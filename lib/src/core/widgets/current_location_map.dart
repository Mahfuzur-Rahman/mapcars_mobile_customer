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
    this.bottomObstruction = 0,
    this.topObstruction = 0,
  });

  /// How much of the map's bottom edge the screen draws over — a sheet, say. The
  /// map is full-bleed, so its own message and retry button are centred in the
  /// part that's actually visible, not the whole screen, where a tall sheet
  /// would sit right on top of them.
  final double bottomObstruction;

  /// How much of the map's top edge the screen draws controls over (a menu
  /// button, say). The error message is kept below it.
  final double topObstruction;

  /// Extra markers to draw on top of the current-location dot.
  final Set<Marker> markers;

  /// Called with the device position once a location fix is obtained
  /// (and again after a retry).
  final void Function(LatLng me)? onLocated;

  /// Called once the camera stops moving, with what the customer is now looking
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

  /// Whether location permission is actually held. This gates the map's
  /// my-location layer, and must NOT be hardcoded to `true`: the Android map
  /// silently skips enabling the blue dot when the platform view is created
  /// without permission, and never retries, because the Dart-side value never
  /// changed. Flipping false -> true after the grant is what makes the plugin
  /// re-apply it — otherwise the dot stays dead until the app is restarted.
  bool _hasPermission = false;
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
        _hasPermission = true;
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
            myLocationEnabled: _hasPermission,
            myLocationButtonEnabled: _hasPermission,
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
          Positioned.fill(
            child: ColoredBox(
              color: Brand.bg,
              child: _Loading(
                topObstruction: widget.topObstruction,
                bottomObstruction: widget.bottomObstruction,
              ),
            ),
          ),
        if (_error != null)
          Positioned.fill(
            child: _LocationError(
              message: _error!,
              topObstruction: widget.topObstruction,
              bottomObstruction: widget.bottomObstruction,
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
  const _Loading({required this.topObstruction, required this.bottomObstruction});

  final double topObstruction;

  final double bottomObstruction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: topObstruction, bottom: bottomObstruction),
        child: const Column(
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
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({
    required this.message,
    required this.topObstruction,
    required this.bottomObstruction,
    required this.opensSettings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String message;
  final double topObstruction;
  final double bottomObstruction;
  final bool opensSettings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Brand.bg,
      // Centred in the strip between the screen's controls and its sheet. When
      // that strip is shorter than the block (a short phone, larger text) the
      // block scrolls inside it rather than running under either.
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, topObstruction, 32, bottomObstruction),
        child: LayoutBuilder(
          builder: (context, box) {
            // The icon is the first thing to go when the strip is short (a
            // large-text phone with the sheet taking the lower half): the
            // message and the button are what the customer needs. Measured, not
            // guessed, so a short message on a roomy screen keeps its icon.
            final scaler = MediaQuery.textScalerOf(context);
            final messageHeight = (TextPainter(
              text: TextSpan(text: message, style: _messageStyle),
              textDirection: TextDirection.ltr,
              textScaler: scaler,
            )..layout(maxWidth: box.maxWidth))
                .height;
            final buttonHeight = math.max(40.0, scaler.scale(14) * 1.25 + 26);
            final withIcon = 42 + 14 + messageHeight + 18 + buttonHeight;
            final showIcon = withIcon <= box.maxHeight;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showIcon) ...[
                        const Icon(Icons.location_off, size: 42, color: Brand.faint),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: _messageStyle,
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
          },
        ),
      ),
    );
  }

  static const _messageStyle =
      TextStyle(color: Brand.sub, fontWeight: FontWeight.w700, fontSize: 14);
}
