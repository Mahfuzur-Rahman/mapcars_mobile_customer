import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'car_icon.dart';
import 'nearby_drivers_service.dart';

/// Polls the API for real nearby online drivers around a center point and
/// reports them as map [Marker]s via [onUpdate]. Positions come from Redis GEO;
/// when the realtime (SignalR) layer lands this can switch from polling to a
/// live subscription — only [_poll] would change.
///
/// Two things make the cars read as *real* rather than as a refreshing list:
///
/// * **Between polls the markers are interpolated**, so a driving car glides
///   along its last→newest fix instead of teleporting every few seconds. A jump
///   larger than [_snapMeters] is treated as a new fix (reconnect / GPS glitch)
///   and snaps rather than sliding across the map.
/// * **Heading falls back to the bearing actually travelled** when the driver's
///   device didn't report one, so a moving car points where it is going instead
///   of always facing north. Rotation turns the short way round.
///
/// The frame ticker only runs while something is still moving, so a screen full
/// of parked cars costs nothing.
class LiveNearbyCars {
  LiveNearbyCars({
    required this.onUpdate,
    required this.service,
    this.radiusMeters = 5000,
    this.limit = 20,
  });

  final void Function(Set<Marker> markers) onUpdate;
  final NearbyDriversService service;

  /// Default query radius, used until the map tells us what it can actually see.
  final double radiusMeters;
  final int limit;

  static const _pollInterval = Duration(seconds: 5);

  /// ~12 fps. Enough for a car crawling across a map to look continuous, cheap
  /// enough to rebuild 20 markers on.
  static const _frameInterval = Duration(milliseconds: 80);

  /// Slide the marker over slightly less than a poll period so it settles just
  /// before the next fix arrives instead of being cut off mid-glide.
  static const _glide = Duration(milliseconds: 4500);

  /// Beyond this, a position change isn't driving — snap to it.
  static const _snapMeters = 400.0;

  /// Below this, movement is GPS noise: keep the previous heading rather than
  /// spinning a parked car around.
  static const _headingMeters = 6.0;

  /// Re-query when the map has been moved at least this far from the last
  /// query point (a small pan shouldn't cost a request).
  static const _recenterMeters = 800.0;

  Timer? _pollTimer;
  Timer? _frameTimer;
  BitmapDescriptor? _icon;
  LatLng? _center;
  double? _radiusOverride;
  bool _busy = false;
  final Map<String, _CarTrack> _tracks = {};

  /// Start (or re-center) polling around [center]. Safe to call again.
  Future<void> start(LatLng center) async {
    _center = center;
    _icon ??= await drawCarIcon();
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
    if (previous != null && _distanceMeters(previous, center) < _recenterMeters) {
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
      final existing = _tracks[d.driverId];
      if (existing == null) {
        _tracks[d.driverId] = _CarTrack(target, d.heading ?? 0);
      } else {
        existing.moveTo(target, d.heading);
      }
    }
    _tracks.removeWhere((id, _) => !seen.contains(id));

    _emit();
    _ensureTicking();
  }

  void _ensureTicking() {
    final moving = _tracks.values.any((t) => !t.settled);
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
    onUpdate({
      for (final entry in _tracks.entries)
        Marker(
          markerId: MarkerId('drv-${entry.key}'),
          position: entry.value.position,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          rotation: entry.value.heading,
          flat: true,
          // The cars are scenery: taps belong to the map underneath.
          consumeTapEvents: false,
        ),
    });
  }
}

/// One driver's animation state: where the marker is sliding from, to, and how
/// far along that slide it currently is.
class _CarTrack {
  _CarTrack(LatLng at, double heading)
      : _from = at,
        _to = at,
        _fromHeading = heading,
        _toHeading = heading,
        _startedAt = DateTime.now(),
        _duration = Duration.zero;

  LatLng _from;
  LatLng _to;
  double _fromHeading;
  double _toHeading;
  DateTime _startedAt;
  Duration _duration;

  bool get settled => _progress >= 1;

  double get _progress {
    if (_duration == Duration.zero) return 1;
    final elapsed = DateTime.now().difference(_startedAt).inMilliseconds;
    return (elapsed / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  LatLng get position {
    final t = _progress;
    if (t >= 1) return _to;
    return LatLng(
      _from.latitude + (_to.latitude - _from.latitude) * t,
      _from.longitude + (_to.longitude - _from.longitude) * t,
    );
  }

  double get heading {
    final t = _progress;
    if (t >= 1) return _toHeading;
    // Turn the short way round: +350° → +10° is a 20° right turn, not 340° left.
    final delta = (_toHeading - _fromHeading + 540) % 360 - 180;
    return (_fromHeading + delta * t + 360) % 360;
  }

  /// Aim the car at its newest fix. [reportedHeading] wins when the device sent
  /// one; otherwise we use the bearing actually travelled.
  void moveTo(LatLng target, double? reportedHeading) {
    final start = position; // continue from wherever the glide got to
    final startHeading = heading;
    final moved = _distanceMeters(start, target);

    _from = start;
    _to = target;
    _fromHeading = startHeading;
    _toHeading = reportedHeading ??
        (moved >= LiveNearbyCars._headingMeters ? _bearing(start, target) : startHeading);
    _startedAt = DateTime.now();
    // A jump this big isn't driving — don't animate a car across the city.
    _duration = moved > LiveNearbyCars._snapMeters ? Duration.zero : LiveNearbyCars._glide;
  }
}

const _earthRadiusMeters = 6371000.0;

/// Equirectangular approximation — accurate well past the few hundred metres a
/// car covers between polls, and far cheaper than haversine every frame.
double _distanceMeters(LatLng a, LatLng b) {
  final latRad = (a.latitude + b.latitude) / 2 * math.pi / 180;
  final dx = (b.longitude - a.longitude) * math.pi / 180 * math.cos(latRad);
  final dy = (b.latitude - a.latitude) * math.pi / 180;
  return math.sqrt(dx * dx + dy * dy) * _earthRadiusMeters;
}

/// Compass bearing a→b in degrees (0 = north, clockwise) — the direction the
/// car is facing when its own device didn't tell us.
double _bearing(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
