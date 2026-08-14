import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/brand.dart';
import '../../models/directions_result.dart';
import '../../models/driver_location.dart';
import '../../services/car_icon.dart';
import '../../services/maps_service.dart';

/// How far away the driver is and how long until they get here.
class TripEta {
  const TripEta({
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.totalMeters,
  });

  final double remainingMeters;
  final int remainingSeconds;
  final double totalMeters;

  double get fraction => totalMeters <= 0
      ? 0
      : (1 - (remainingMeters / totalMeters)).clamp(0.0, 1.0);

  String get distanceLabel {
    final miles = remainingMeters / 1609.344;
    if (miles < 0.2) return '${(remainingMeters * 3.28084).round()} ft';
    return '${miles.toStringAsFixed(1)} mi';
  }

  String get etaLabel {
    final minutes = (remainingSeconds / 60).round();
    return minutes < 1 ? '< 1 min' : '$minutes min';
  }
}

/// The rider's live map: the driver's real car moving along a real route toward
/// [destination] (their pickup while waiting, their drop-off once on board).
///
/// The driver's position comes from [driver] — pushed over SignalR by the
/// driver's app and relayed by the API — and *not* from a made-up offset from
/// the pickup point, which is what this screen used to draw.
class TripTrackingMap extends ConsumerStatefulWidget {
  const TripTrackingMap({
    super.key,
    required this.driver,
    required this.destination,
    this.destinationLabel = 'Destination',
    this.isPickup = true,
    this.onEta,
  });

  /// Live driver position; null until a driver is assigned and reporting.
  final DriverLocation? driver;

  final LatLng destination;
  final String destinationLabel;

  /// Waiting for pickup (green leg) vs on board heading to drop-off (blue).
  final bool isPickup;

  final ValueChanged<TripEta>? onEta;

  @override
  ConsumerState<TripTrackingMap> createState() => _TripTrackingMapState();
}

class _TripTrackingMapState extends ConsumerState<TripTrackingMap> {
  /// Directions calls are billed per request, so the route is only re-fetched
  /// once the driver has actually moved a meaningful distance — the ETA in
  /// between is interpolated along the polyline we already have.
  static const _rerouteMeters = 150.0;
  static const _rerouteMinGap = Duration(seconds: 25);

  /// How far the driver can drift before the camera re-frames the pair.
  static const _refitMeters = 250.0;

  static const _fallback =
      CameraPosition(target: LatLng(51.5074, -0.1278), zoom: 12);

  GoogleMapController? _controller;
  BitmapDescriptor? _carIcon;

  DirectionsResult? _route;
  LatLng? _routeFrom;
  DateTime? _routeFetchedAt;
  bool _fetchingRoute = false;

  LatLng? _lastFitAt;

  /// Riders pan the map to look around; don't yank it back under their finger.
  bool _following = true;
  bool _selfMove = false;

  @override
  void initState() {
    super.initState();
    drawCarIcon().then((icon) {
      if (mounted) setState(() => _carIcon = icon);
    });
    _syncRoute();
  }

  @override
  void didUpdateWidget(TripTrackingMap old) {
    super.didUpdateWidget(old);
    if (old.destination != widget.destination) {
      // Pickup → drop-off: the whole route is a different journey.
      _route = null;
      _routeFrom = null;
      _routeFetchedAt = null;
      _lastFitAt = null;
    }
    _syncRoute();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _syncRoute() {
    final driver = widget.driver;
    if (driver == null) return;
    final at = LatLng(driver.lat, driver.lng);

    _emitEta(at);
    if (_shouldRefetch(at)) unawaited(_fetchRoute(at));
    if (_following && _shouldRefit(at)) unawaited(_fitBounds(at));
  }

  bool _shouldRefetch(LatLng at) {
    if (_fetchingRoute) return false;
    if (_route == null || _routeFrom == null) return true;

    final since = _routeFetchedAt;
    if (since != null && DateTime.now().difference(since) < _rerouteMinGap) {
      return false;
    }
    return _metersBetween(at, _routeFrom!) >= _rerouteMeters;
  }

  bool _shouldRefit(LatLng at) =>
      _lastFitAt == null || _metersBetween(at, _lastFitAt!) >= _refitMeters;

  Future<void> _fetchRoute(LatLng from) async {
    _fetchingRoute = true;
    try {
      final route = await ref
          .read(googleMapsServiceProvider)
          .directions(origin: from, destination: widget.destination);
      if (!mounted) return;
      setState(() {
        _route = route;
        _routeFrom = from;
        _routeFetchedAt = DateTime.now();
      });
      _emitEta(from);
    } catch (_) {
      // A missing route just means the straight-line fallback in _emitEta and a
      // direct line on the map — never an error banner on the rider's screen.
    } finally {
      _fetchingRoute = false;
    }
  }

  void _emitEta(LatLng at) {
    final onEta = widget.onEta;
    if (onEta == null) return;

    final route = _route;
    if (route == null || route.points.length < 2) {
      final meters = _metersBetween(at, widget.destination) * 1.35;
      onEta(TripEta(
        remainingMeters: meters,
        remainingSeconds: (meters / 1609.344 / 18.0 * 3600).round(),
        totalMeters: meters,
      ));
      return;
    }

    final remaining = _remainingAlongRoute(at, route.points);
    final total = route.distanceMeters.toDouble();
    final ratio = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);

    onEta(TripEta(
      remainingMeters: remaining,
      remainingSeconds: (route.durationSeconds * ratio).round(),
      totalMeters: total,
    ));
  }

  double _remainingAlongRoute(LatLng at, List<LatLng> points) {
    final i = _nearestIndex(at, points);
    var total = _metersBetween(at, points[i]);
    for (var j = i; j < points.length - 1; j++) {
      total += _metersBetween(points[j], points[j + 1]);
    }
    return total;
  }

  int _nearestIndex(LatLng at, List<LatLng> points) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = _metersBetween(at, points[i]);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  Future<void> _fitBounds(LatLng driver) async {
    final controller = _controller;
    if (controller == null) return;

    final destination = widget.destination;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(driver.latitude, destination.latitude),
        math.min(driver.longitude, destination.longitude),
      ),
      northeast: LatLng(
        math.max(driver.latitude, destination.latitude),
        math.max(driver.longitude, destination.longitude),
      ),
    );

    _lastFitAt = driver;
    _selfMove = true;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
    } catch (_) {
      // A degenerate bounds (driver effectively on top of the destination) can
      // fail to fit — centring on the pair is a fine outcome there.
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(driver, 15.5),
      );
    }
    _selfMove = false;
  }

  /// The remaining leg only, so the line shortens as the driver closes in.
  List<LatLng> _polylineAhead(LatLng? driver) {
    final route = _route;
    if (route == null || route.points.isEmpty) {
      // No route yet — a straight hint line beats an empty map.
      return driver == null ? const [] : [driver, widget.destination];
    }
    if (driver == null) return route.points;
    final i = _nearestIndex(driver, route.points);
    return [driver, ...route.points.sublist(i)];
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final driverAt = driver == null ? null : LatLng(driver.lat, driver.lng);
    final ahead = _polylineAhead(driverAt);
    final legColour = widget.isPickup ? Brand.green : Brand.blue;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: driverAt == null
                ? CameraPosition(target: widget.destination, zoom: 14.5)
                : _fallback,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) {
              _controller = c;
              if (driverAt != null) {
                _fitBounds(driverAt);
              } else {
                c.animateCamera(
                    CameraUpdate.newLatLngZoom(widget.destination, 14.5));
              }
            },
            onCameraMoveStarted: () {
              if (!_selfMove && _following) setState(() => _following = false);
            },
            markers: {
              Marker(
                markerId: const MarkerId('destination'),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(widget.isPickup
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueAzure),
                infoWindow: InfoWindow(
                  title: widget.isPickup ? 'Pickup' : 'Destination',
                  snippet: widget.destinationLabel,
                ),
              ),
              if (driverAt != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: driverAt,
                  rotation: driver!.heading ?? 0,
                  anchor: const Offset(0.5, 0.5),
                  flat: true,
                  zIndexInt: 2,
                  // Dim the car once its fix is stale, so a driver whose phone
                  // dropped off doesn't look like they're parked mid-road.
                  alpha: driver.isStale ? 0.45 : 1.0,
                  icon: _carIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure),
                ),
            },
            polylines: {
              if (ahead.length >= 2)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: ahead,
                  color: legColour,
                  width: 5,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
            },
          ),
        ),
        if (!_following)
          Positioned(
            right: 14,
            bottom: 14,
            child: _RefitPill(onTap: () {
              setState(() => _following = true);
              final at = driverAt;
              if (at != null) {
                _fitBounds(at);
              } else {
                _controller?.animateCamera(
                    CameraUpdate.newLatLngZoom(widget.destination, 14.5));
              }
            }),
          ),
      ],
    );
  }
}

class _RefitPill extends StatelessWidget {
  const _RefitPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x2916202E),
                  blurRadius: 14,
                  offset: Offset(0, 4)),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.center_focus_strong, size: 17, color: Brand.blue),
              SizedBox(width: 7),
              Text('Show route',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Brand.ink)),
            ],
          ),
        ),
      );
}

/// Great-circle distance in metres.
double _metersBetween(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLng = _radians(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(a.latitude)) *
          math.cos(_radians(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _radians(double degrees) => degrees * math.pi / 180.0;
