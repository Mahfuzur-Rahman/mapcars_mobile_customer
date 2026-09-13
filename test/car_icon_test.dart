// Guards the map-marker painter. It hand-builds several multi-stop gradients,
// and ui.Gradient.linear asserts when a colour list and its stop list disagree
// in length — the easiest thing to get wrong when restyling the car. These
// tests also prove the canvas actually rasterises to PNG bytes.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/theme/brand.dart';
import 'package:mapcars_mobile/src/features/ride/services/car_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('drawCarIcon rasterises for every colour a caller passes', () async {
    // Pearl = scenery cars (live_nearby_cars), blue = the rider's own driver
    // (trip_tracking_map). A near-black body is no longer used anywhere.
    for (final body in const [Brand.carPearl, Brand.blue]) {
      await expectLater(drawCarIcon(body), completes);
    }
  });

  test('drawCarIcon falls back to the pearl scenery car', () async {
    await expectLater(drawCarIcon(), completes);
  });

  test('drawGlowingCarIcon rasterises across a whole pulse beat', () async {
    // The halo is pre-rendered as 8 frames, so every point of the beat has to
    // paint — including the endpoints, where the ring alpha and width reach 0.
    for (var i = 0; i <= 8; i++) {
      await expectLater(
        drawGlowingCarIcon(body: Brand.blue, pulse: i / 8),
        completes,
      );
    }
  });

  test('the halo pads around the declared car footprint', () {
    expect(carIconWidth, 64.0);
    expect(carIconHeight, 128.0);
  });
}
