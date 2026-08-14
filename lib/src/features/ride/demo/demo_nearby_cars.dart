// ─────────────────────────────────────────────────────────────────────────────
// DEMO ONLY — FAKE NEARBY CARS, JUST FOR TESTING. REMOVE LATER.
//
// Spawns 4 pretend driver cars a few blocks (200–500 m) from wherever the
// user is and drives them around at random so the home map feels alive.
// Delete this whole file (and its wiring in `home_screen.dart`) once real
// driver locations stream from the API (Redis GEO + SignalR).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simulates a handful of cars wandering near [start]'s center point and
/// reports them as map [Marker]s via [onUpdate] roughly once a second.
class DemoNearbyCars {
  DemoNearbyCars({required this.onUpdate, this.carCount = 4});

  /// Receives the freshly-moved car markers every tick.
  final void Function(Set<Marker> markers) onUpdate;

  final int carCount;

  static const _tick = Duration(seconds: 1);
  static const _minSpawnMeters = 200.0; // "some blocks away"
  static const _maxSpawnMeters = 500.0;
  static const _maxWanderMeters = 800.0; // steer back when past this

  final _rng = math.Random();
  final List<_DemoCar> _cars = [];
  List<BitmapDescriptor> _icons = const [];
  LatLng? _center;
  Timer? _timer;

  /// Spawns the cars around [center] and starts them moving. Safe to call
  /// again (e.g. after a location retry) — it just re-seeds the fleet.
  Future<void> start(LatLng center) async {
    stop();
    _center = center;
    _icons = await Future.wait(
      _carColors.map((c) => _drawCarIcon(c)),
    );
    _cars
      ..clear()
      ..addAll(List.generate(carCount, (i) {
        final bearing = _rng.nextDouble() * 360;
        final distance = _minSpawnMeters +
            _rng.nextDouble() * (_maxSpawnMeters - _minSpawnMeters);
        return _DemoCar(
          id: 'demo-car-$i',
          position: _offset(center, bearing, distance),
          headingDeg: _rng.nextDouble() * 360,
          speedMps: 6 + _rng.nextDouble() * 6, // ~city driving speed
          icon: _icons[i % _icons.length],
        );
      }));
    _emit();
    _timer = Timer.periodic(_tick, (_) => _move());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _move() {
    final center = _center;
    if (center == null) return;
    for (final car in _cars) {
      // Occasionally take a "turn", like at a junction.
      if (_rng.nextDouble() < 0.3) {
        car.headingDeg += (_rng.nextDouble() - 0.5) * 80;
      }
      // Drifted too far from the user — head back toward them.
      if (_distanceMeters(car.position, center) > _maxWanderMeters) {
        car.headingDeg = _bearingDeg(car.position, center);
      }
      car.position =
          _offset(car.position, car.headingDeg, car.speedMps * _tick.inSeconds);
    }
    _emit();
  }

  void _emit() {
    onUpdate({
      for (final car in _cars)
        Marker(
          markerId: MarkerId(car.id),
          position: car.position,
          icon: car.icon,
          rotation: car.headingDeg,
          flat: true, // rotate with the map like a real car
          anchor: const Offset(0.5, 0.5),
        ),
    });
  }

  // ── geo helpers ────────────────────────────────────────────────────────────

  static LatLng _offset(LatLng from, double bearingDeg, double meters) {
    const earthMetersPerDegLat = 111320.0;
    final rad = bearingDeg * math.pi / 180;
    final dLat = meters * math.cos(rad) / earthMetersPerDegLat;
    final dLng = meters *
        math.sin(rad) /
        (earthMetersPerDegLat * math.cos(from.latitude * math.pi / 180));
    return LatLng(from.latitude + dLat, from.longitude + dLng);
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const earthMetersPerDegLat = 111320.0;
    final dLat = (b.latitude - a.latitude) * earthMetersPerDegLat;
    final dLng = (b.longitude - a.longitude) *
        earthMetersPerDegLat *
        math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  static double _bearingDeg(LatLng from, LatLng to) {
    final dLat = to.latitude - from.latitude;
    final dLng = (to.longitude - from.longitude) *
        math.cos(from.latitude * math.pi / 180);
    return math.atan2(dLng, dLat) * 180 / math.pi;
  }

  // ── icon drawing ───────────────────────────────────────────────────────────

  // Uber-style fleet: all sleek near-black cars, with barely-different tints
  // so overlapping cars still read as separate.
  static const _carColors = [
    Color(0xFF15181C), // black
    Color(0xFF1C2026), // graphite
    Color(0xFF23272E), // gunmetal
    Color(0xFF101317), // jet
  ];

  static Color _shade(Color c, double amount) =>
      Color.lerp(c, amount >= 0 ? Colors.white : Colors.black, amount.abs())!;

  /// Draws an Uber-style top-down sedan (nose pointing north): curved body
  /// with a side-to-side sheen, dark glass, roof panel, mirrors and lights.
  static Future<BitmapDescriptor> _drawCarIcon(Color body) async {
    const w = 64, h = 128;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Soft ground shadow.
    canvas.drawOval(
      const Rect.fromLTWH(12, 12, 40, 112),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Body — smooth sedan outline (narrow nose, wide flanks, rounded tail).
    final bodyPath = Path()
      ..moveTo(32, 4)
      ..cubicTo(45, 4, 51, 14, 52, 30)
      ..cubicTo(53.5, 48, 53.5, 78, 52, 98)
      ..cubicTo(51, 116, 44, 124, 32, 124)
      ..cubicTo(20, 124, 13, 116, 12, 98)
      ..cubicTo(10.5, 78, 10.5, 48, 12, 30)
      ..cubicTo(13, 14, 19, 4, 32, 4)
      ..close();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          const Offset(12, 0),
          const Offset(52, 0),
          [_shade(body, 0.22), body, _shade(body, -0.35)],
          [0.0, 0.45, 1.0],
        ),
    );

    // Side mirrors.
    final trim = Paint()
      ..isAntiAlias = true
      ..color = _shade(body, -0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 40, 9, 6), const Radius.circular(3)),
      trim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(50, 40, 9, 6), const Radius.circular(3)),
      trim,
    );

    // Glass — dark blue-gray like tinted windows.
    final glass = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFF2B333E);
    final windshield = Path()
      ..moveTo(15, 38)
      ..quadraticBezierTo(32, 33, 49, 38)
      ..lineTo(46, 52)
      ..quadraticBezierTo(32, 47, 18, 52)
      ..close();
    canvas.drawPath(windshield, glass);
    final rearWindow = Path()
      ..moveTo(17, 96)
      ..quadraticBezierTo(32, 102, 47, 96)
      ..lineTo(45, 108)
      ..quadraticBezierTo(32, 113, 19, 108)
      ..close();
    canvas.drawPath(rearWindow, glass);
    // Thin side windows along the roof.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 56, 5, 36), const Radius.circular(2.5)),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(45, 56, 5, 36), const Radius.circular(2.5)),
      glass,
    );

    // Roof panel, a touch lighter than the body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(21, 55, 22, 38), const Radius.circular(9)),
      Paint()
        ..isAntiAlias = true
        ..color = _shade(body, 0.10),
    );

    // Headlights + tail lights.
    final headlight = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFE9EEF4).withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 8, 9, 4), const Radius.circular(2)),
      headlight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(35, 8, 9, 4), const Radius.circular(2)),
      headlight,
    );
    final taillight = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFC0392B).withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 117, 8, 3.5), const Radius.circular(2)),
      taillight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(34, 117, 8, 3.5), const Radius.circular(2)),
      taillight,
    );

    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: 3.0,
    );
  }
}

class _DemoCar {
  _DemoCar({
    required this.id,
    required this.position,
    required this.headingDeg,
    required this.speedMps,
    required this.icon,
  });

  final String id;
  final double speedMps;
  final BitmapDescriptor icon;
  LatLng position;
  double headingDeg;
}
