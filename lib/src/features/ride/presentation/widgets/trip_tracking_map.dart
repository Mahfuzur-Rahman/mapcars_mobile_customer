import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/geo/car_motion.dart';
import '../../../../core/geo/geo_math.dart';
import '../../../../core/geo/route_path.dart';
import '../../../../core/location/location_service.dart';
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

  /// ~12 fps. Enough for a car to look like it is driving rather than
  /// teleporting, cheap enough to rebuild two markers on. Same cadence the
  /// home-screen nearby-cars layer already runs at.
  static const _frameInterval = Duration(milliseconds: 80);

  /// One full breath of the halo.
  static const _pulsePeriod = Duration(milliseconds: 1600);

  GoogleMapController? _controller;
  BitmapDescriptor? _carIcon;

  /// Pre-rendered halo frames, cycled to animate the glow. Google Maps markers
  /// take a static bitmap, so an animated marker *is* a sequence of bitmaps —
  /// rendered once here rather than per frame.
  List<BitmapDescriptor> _pulseFrames = const [];

  Timer? _ticker;

  /// Owns where the car is *drawn*: it trails the newest fix while the glide
  /// plays out, and follows the route polyline rather than cutting straight
  /// across the gap between two GPS fixes. The ETA and the camera still key off
  /// the real fix ([widget.driver]); only the marker is interpolated.
  final CarMotion _motion = CarMotion();

  /// Whether location permission is held. Gates this map's own blue dot — see
  /// [LocationService.hasPermission] for why it can't just be `true`.
  bool _hasPermission = false;

  DirectionsResult? _route;

  /// [_route]'s polyline, prepared for projection and travel along.
  RoutePath? _path;
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
    // Blue: this is the rider's *own* driver. The scenery cars around it are
    // pearl (see live_nearby_cars), so the colour alone identifies it even at
    // the zoom levels where the halo is off.
    drawCarIcon(Brand.blue).then((icon) {
      if (mounted) setState(() => _carIcon = icon);
    });
    unawaited(_buildPulseFrames());

    final at = widget.driver;
    if (at != null) {
      _motion.onFix(LatLng(at.lat, at.lng), reportedHeading: at.heading);
    }
    _ticker = Timer.periodic(_frameInterval, (_) => _onFrame());

    const LocationService().hasPermission().then((granted) {
      if (mounted && granted) setState(() => _hasPermission = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRoute();
    });
  }

  /// Renders one beat of the halo as a short strip of bitmaps. Eight frames is
  /// enough for the ping to read as continuous at this size.
  Future<void> _buildPulseFrames() async {
    const count = 8;
    final frames = <BitmapDescriptor>[];
    for (var i = 0; i < count; i++) {
      frames.add(await drawGlowingCarIcon(body: Brand.blue, pulse: i / count));
    }
    if (mounted) setState(() => _pulseFrames = frames);
  }

  /// Repaints while anything is animating. [CarMotion] derives the car's
  /// position from the clock on read, so there is nothing to advance here.
  void _onFrame() {
    if (!mounted) return;

    // Only repaint when there is actually something moving. Without this guard
    // the map rebuilt 12×/second for the whole of a ride — including on the
    // in-progress screen, which draws no halo at all.
    final animatingHalo = _pulseFrames.isNotEmpty &&
        widget.isPickup &&
        widget.driver != null &&
        widget.driver!.isStale != true;
    if (animatingHalo || _motion.isMoving) setState(() {});
  }

  /// Frame index for the halo, derived from the wall clock so the beat is
  /// steady even if a frame is dropped.
  BitmapDescriptor? get _pulseIcon {
    if (_pulseFrames.isEmpty) return null;
    final ms = DateTime.now().millisecondsSinceEpoch % _pulsePeriod.inMilliseconds;
    final i = (ms / _pulsePeriod.inMilliseconds * _pulseFrames.length).floor();
    return _pulseFrames[i % _pulseFrames.length];
  }

  @override
  void didUpdateWidget(TripTrackingMap old) {
    super.didUpdateWidget(old);
    if (old.destination != widget.destination) {
      // Pickup → drop-off: the whole route is a different journey.
      _route = null;
      _path = null;
      _motion.route = null;
      _routeFrom = null;
      _routeFetchedAt = null;
      _lastFitAt = null;
    }
    _absorbFix(old.driver, widget.driver);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRoute();
    });
  }

  /// Fold a new driver fix into the glide, so the car drives to it over the next
  /// few seconds instead of jumping. Without this the rider sees a car that
  /// stands still and then teleports, which reads as a broken map rather than as
  /// someone driving toward them.
  void _absorbFix(DriverLocation? before, DriverLocation? now) {
    if (now == null) return; // build() draws nothing while there is no driver
    if (before != null && before.lat == now.lat && before.lng == now.lng) {
      // The same fix re-delivered (push and poll agreeing). Folding it in again
      // would restart the glide and drag the observed cadence down with it.
      return;
    }
    _motion.onFix(LatLng(now.lat, now.lng), reportedHeading: now.heading);
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
    return metersBetween(at, _routeFrom!) >= _rerouteMeters;
  }

  bool _shouldRefit(LatLng at) =>
      _lastFitAt == null || metersBetween(at, _lastFitAt!) >= _refitMeters;

  Future<void> _fetchRoute(LatLng from) async {
    _fetchingRoute = true;
    try {
      final route = await ref
          .read(googleMapsServiceProvider)
          .directions(origin: from, destination: widget.destination);
      if (!mounted) return;
      setState(() {
        _route = route;
        _path = RoutePath(route.points);
        // Hand the car the new line to follow. CarMotion rebases onto where it
        // is currently drawn, so a refetch never teleports it.
        _motion.route = _path;
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
    final path = _path;
    final TripEta eta;
    if (route == null || path == null || !path.isUsable) {
      final meters = metersBetween(at, widget.destination) * 1.35;
      eta = TripEta(
        remainingMeters: meters,
        remainingSeconds: (meters / 1609.344 / 18.0 * 3600).round(),
        totalMeters: meters,
      );
    } else {
      final remaining = path.remainingFrom(
          path.project(at, nearAlongMeters: _motion.alongMeters).alongMeters);
      final total = route.distanceMeters.toDouble();
      final ratio = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);

      eta = TripEta(
        remainingMeters: remaining,
        remainingSeconds: (route.durationSeconds * ratio).round(),
        totalMeters: total,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onEta(eta);
    });
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
    final path = _path;
    if (path == null || !path.isUsable) {
      // No route yet — a straight hint line beats an empty map.
      return driver == null ? const [] : [driver, widget.destination];
    }
    if (driver == null) return path.points;

    // On the route, the line starts exactly under the car. Off it (a wrong
    // turn, or a route gone stale), join the car to the road so the two do not
    // read as unrelated.
    final along = _motion.alongMeters;
    if (along != null) return path.pointsFrom(along);
    return [driver, ...path.pointsFrom(path.project(driver).alongMeters)];
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    // The drawn position, mid-glide toward the newest fix.
    final driverAt =
        driver == null ? null : (_motion.position ?? LatLng(driver.lat, driver.lng));
    final ahead = _polylineAhead(driverAt);
    final legColour = widget.isPickup ? Brand.green : Brand.blue;

    // Halo only while the car is coming *to* the rider. Once they're on board it
    // is their own car and needs no picking out, and a permanent ping on the
    // in-progress screen is just noise.
    final highlight = widget.isPickup && driver?.isStale != true;
    final carIcon = (highlight ? _pulseIcon : null) ??
        _carIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: driverAt == null
                ? CameraPosition(target: widget.destination, zoom: 14.5)
                : _fallback,
            myLocationEnabled: _hasPermission,
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
                  rotation: _motion.heading,
                  anchor: const Offset(0.5, 0.5),
                  flat: true,
                  zIndexInt: 2,
                  // Dim the car once its fix is stale, so a driver whose phone
                  // dropped off doesn't look like they're parked mid-road.
                  alpha: driver!.isStale ? 0.45 : 1.0,
                  icon: carIcon,
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
