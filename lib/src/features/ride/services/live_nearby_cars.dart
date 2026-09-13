import 'dart:async';
import 'dart:ui' show Offset;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/geo/car_motion.dart';
import '../../../core/geo/geo_math.dart';
import '../../../core/theme/brand.dart';
import 'car_icon.dart';
import 'nearby_drivers_service.dart';

/// Polls the API for real nearby online drivers around a center point and
/// reports them as map [Marker]s via [onUpdate]. Positions come from Redis GEO;
/// when the realtime (SignalR) layer lands this can switch from polling to a
/// live subscription — only [_poll] would change.
///
/// What makes the cars read as *real* rather than as a refreshing list is
/// [CarMotion], which owns the interpolation: a car glides from where it is
/// drawn to its newest fix, turns the short way round, keeps its heading when a
/// change is just GPS noise, and snaps rather than sliding when a jump is too
/// big to be driving. These cars have no route to follow, so the road-snapping
/// half of CarMotion is unused here.
///
/// The frame ticker only runs while something is still moving, so a screen full
/// of parked cars costs nothing.
class LiveNearbyCars {
  LiveNearbyCars({
    required this.onUpdate,
    required this.service,
    this.radiusMeters = 5000,
    this.limit = 50,
  });

  final void Function(Set<Marker> markers) onUpdate;
  final NearbyDriversService service;

  /// Default query radius, used until the map tells us what it can actually see.
  final double radiusMeters;

  /// How many cars one poll may return. Matches the API's default so a
  /// zoomed-out map isn't quietly cut to an arbitrary handful of the drivers
  /// actually on screen; the API caps it at 100.
  final int limit;

  static const _pollInterval = Duration(seconds: 5);

  /// ~12 fps. Enough for a car crawling across a map to look continuous, cheap
  /// enough to rebuild 20 markers on.
  static const _frameInterval = Duration(milliseconds: 80);

  /// Re-query when the map has been moved at least this far from the last
  /// query point (a small pan shouldn't cost a request).
  static const _recenterMeters = 800.0;

  Timer? _pollTimer;
  Timer? _frameTimer;
  BitmapDescriptor? _icon;
  LatLng? _center;
  double? _radiusOverride;
  bool _busy = false;
  final Map<String, CarMotion> _tracks = {};

  /// Start (or re-center) polling around [center]. Safe to call again.
  Future<void> start(LatLng center) async {
    _center = center;
    // Pearl: these are ambient scenery cars, so they must recede. The rider's
    // own driver is drawn in Brand.blue by trip_tracking_map, and the contrast
    // between the two is what makes "that one is mine" readable at a glance.
    _icon ??= await drawCarIcon(Brand.carPearl);
    await _poll();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Follow the map: re-query around [center] once the user has panned far
  /// enough, so cars show up where the rider is actually looking. [radiusMeters]
  /// (usually derived from the visible region) widens the query when zoomed out.
  void recenter(LatLng center, {double? radiusMeters}) {
    final previous = _center;
    _radiusOverride = radiusMeters;
    if (previous != null && metersBetween(previous, center) < _recenterMeters) {
      return;
    }
    _center = center;
    if (_pollTimer == null) return; // not started yet — start() will do the first poll
    unawaited(_poll());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _frameTimer?.cancel();
    _frameTimer = null;
    _tracks.clear();
  }

  Future<void> _poll() async {
    final center = _center;
    if (center == null || _busy) return;
    _busy = true;
    try {
      final drivers = await service.nearby(
        center.latitude,
        center.longitude,
        radiusMeters: _radiusOverride ?? radiusMeters,
        limit: limit,
      );
      _absorb(drivers);
    } catch (_) {
      // Transient error / not signed in (401) — keep the last markers; the next
      // tick retries. No user-facing error for a background map refresh.
    } finally {
      _busy = false;
    }
  }

  /// Fold a fresh poll into the tracks: move existing cars, add new ones, and
  /// drop any driver the API no longer returns (offline, or drove out of range).
  void _absorb(List<NearbyDriver> drivers) {
    final seen = <String>{};
    for (final d in drivers) {
      seen.add(d.driverId);
      final target = LatLng(d.lat, d.lng);
      (_tracks[d.driverId] ??= CarMotion())
          .onFix(target, reportedHeading: d.heading);
    }
    _tracks.removeWhere((id, _) => !seen.contains(id));

    _emit();
    _ensureTicking();
  }

  void _ensureTicking() {
    final moving = _tracks.values.any((car) => car.isMoving);
    if (moving) {
      _frameTimer ??= Timer.periodic(_frameInterval, (_) => _tick());
    } else {
      _frameTimer?.cancel();
      _frameTimer = null;
    }
  }

  void _tick() {
    _emit();
    _ensureTicking();
  }

  void _emit() {
    final icon = _icon;
    if (icon == null) return;

    final markers = <Marker>{};
    for (final entry in _tracks.entries) {
      final at = entry.value.position;
      if (at == null) continue; // no fix folded in yet
      markers.add(Marker(
        markerId: MarkerId('drv-${entry.key}'),
        position: at,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        rotation: entry.value.heading,
        flat: true,
        // The cars are scenery: taps belong to the map underneath.
        consumeTapEvents: false,
      ));
    }
    onUpdate(markers);
  }
}
