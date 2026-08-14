import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/location_service.dart';
import '../theme/brand.dart';

/// A live Google map centered on the device's current location, with the blue
/// "my location" dot and re-center button. Handles the permission / GPS-off /
/// loading states in-line so screens can just drop it in as a full-bleed layer.
///
/// Requires native config: location permissions + a Maps SDK for Android key in
/// `android/local.properties` (MAPS_API_KEY). See instruction.md §6.
class CurrentLocationMap extends StatefulWidget {
  const CurrentLocationMap({
    super.key,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.onLocated,
    this.onCameraSettled,
    this.zoom = 15.5,
  });

  /// Extra markers to draw on top of the current-location dot.
  final Set<Marker> markers;

  /// Called with the device position once a location fix is obtained
  /// (and again after a retry).
  final void Function(LatLng me)? onLocated;

  /// Called once the camera stops moving, with what the rider is now looking
  /// at: the map centre and the radius (metres) from it to the edge of the
  /// visible region. Lets a live layer re-query for the area actually on
  /// screen instead of forever around the first GPS fix.
  final void Function(LatLng center, double visibleRadiusMeters)? onCameraSettled;

  /// Optional routes/overlays.
  final Set<Polyline> polylines;

  /// Called once the underlying [GoogleMapController] is ready.
  final void Function(GoogleMapController controller)? onMapCreated;

  /// Initial camera zoom.
  final double zoom;

  @override
  State<CurrentLocationMap> createState() => _CurrentLocationMapState();
}

class _CurrentLocationMapState extends State<CurrentLocationMap> {
  static const _locationService = LocationService();

  // Fallback camera target (central London) shown only until we get a fix.
  static const _fallback = CameraPosition(target: LatLng(51.5074, -0.1278), zoom: 11);

  GoogleMapController? _controller;
  LatLng? _me;
  LatLng? _camera;
  String? _error;
  bool _errorOpensSettings = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await _locationService.currentPosition();
      if (!mounted) return;
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _me = me;
        _loading = false;
      });
      widget.onLocated?.call(me);
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: me, zoom: widget.zoom)),
      );
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorOpensSettings = e.openAppSettings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't get your location. Please try again.";
        _errorOpensSettings = false;
        _loading = false;
      });
    }
  }

  /// Hand the settled camera to [CurrentLocationMap.onCameraSettled] along with
  /// how much ground is on screen, so callers can size their query to the view.
  Future<void> _reportCamera() async {
    final report = widget.onCameraSettled;
    final center = _camera;
    final controller = _controller;
    if (report == null || center == null || controller == null) return;
    try {
      final region = await controller.getVisibleRegion();
      report(center, _radiusOf(region, center));
    } catch (_) {
      // Controller disposed mid-gesture — the next idle reports again.
    }
  }

  /// Metres from [center] to the north-east corner of the visible region: the
  /// radius of a circle that covers everything on screen.
  static double _radiusOf(LatLngBounds region, LatLng center) {
    const earthRadiusMeters = 6371000.0;
    final corner = region.northeast;
    final latRad = (center.latitude + corner.latitude) / 2 * math.pi / 180;
    final dx = (corner.longitude - center.longitude) * math.pi / 180 * math.cos(latRad);
    final dy = (corner.latitude - center.latitude) * math.pi / 180;
    return math.sqrt(dx * dx + dy * dy) * earthRadiusMeters;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition:
                _me == null ? _fallback : CameraPosition(target: _me!, zoom: widget.zoom),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: widget.markers,
            polylines: widget.polylines,
            onCameraMove: (pos) => _camera = pos.target,
            onCameraIdle: _reportCamera,
            onMapCreated: (c) {
              _controller = c;
              widget.onMapCreated?.call(c);
              if (_me != null) {
                c.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _me!, zoom: widget.zoom),
                  ),
                );
              }
            },
          ),
        ),
        if (_loading)
          const Positioned.fill(child: ColoredBox(color: Brand.bg, child: _Loading())),
        if (_error != null)
          Positioned.fill(
            child: _LocationError(
              message: _error!,
              opensSettings: _errorOpensSettings,
              onRetry: _resolveLocation,
              onOpenSettings: () => _locationService.openSettings(),
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Brand.blue),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Finding your location…',
            style: TextStyle(color: Brand.sub, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({
    required this.message,
    required this.opensSettings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String message;
  final bool opensSettings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Brand.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 42, color: Brand.faint),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Brand.sub, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: opensSettings ? onOpenSettings : onRetry,
                style: FilledButton.styleFrom(backgroundColor: Brand.blue),
                child: Text(opensSettings ? 'Open settings' : 'Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
