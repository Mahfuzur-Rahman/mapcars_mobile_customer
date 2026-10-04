// The customer tab bar (Home / Activity / Account) must sit fully above the
// system nav bar. It was a fixed 84dp with 18dp of bottom padding, so under
// Android 15's forced edge-to-edge a 48dp 3-button bar covered the labels and
// the lower half of every tab's hit area.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/theme/app_theme.dart';
import 'package:mapcars_mobile/src/core/widgets/mc.dart';
import 'package:mapcars_mobile/src/core/widgets/mc_tab_bar.dart';
import 'package:mapcars_mobile/src/features/account/presentation/history_screen.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip.dart';
import 'package:mapcars_mobile/src/features/ride/services/ride_service.dart';

import 'support/reachability.dart';

Widget _withTabBar() => const Scaffold(
      bottomNavigationBar: McTabBar(active: 'activity'),
      body: SizedBox.expand(),
    );

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('every label and icon clears a 48dp nav bar (text x$scale)',
        (tester) async {
      await pumpOnSmallPhone(tester, _withTabBar(), textScale: scale);

      for (final label in ['Home', 'Activity', 'Account']) {
        expectReachableWithoutScrolling(tester, find.text(label));
      }
      final icons = find.descendant(
          of: find.byType(McTabBar), matching: find.byType(Ico));
      expect(icons, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expectReachableWithoutScrolling(tester, icons.at(i));
      }
    });
  }

  testWidgets('grows past the inset, so its background still reaches the edge',
      (tester) async {
    await pumpOnSmallPhone(tester, _withTabBar());
    final bar = tester.getRect(find.byType(McTabBar));
    // 66 of bar proper + whatever sits beneath the labels (max(18, inset)).
    expect(bar.height, 66 + kNavBarInset);
    expect(bar.bottom, kSmallPhone.height);
  });

  testWidgets('a small inset (iPhone home indicator) is absorbed by the 18dp',
      (tester) async {
    // 34dp indicator: the 18dp that always sat under the labels is replaced by
    // the inset, not added to — 100dp, not 118.
    await pumpOnSmallPhone(tester, _withTabBar());
    tester.view
      ..padding = const FakeViewPadding(bottom: 34)
      ..viewPadding = const FakeViewPadding(bottom: 34);
    await tester.pump();
    expect(tester.getSize(find.byType(McTabBar)).height, 66 + 34);

    // And an inset smaller than 18 changes nothing.
    tester.view
      ..padding = const FakeViewPadding(bottom: 10)
      ..viewPadding = const FakeViewPadding(bottom: 10);
    await tester.pump();
    expect(tester.getSize(find.byType(McTabBar)).height, 84);
  });

  testWidgets('is the original 84dp when there is no inset', (tester) async {
    await pumpOnSmallPhone(tester, _withTabBar());
    tester.view
      ..padding = FakeViewPadding.zero
      ..viewPadding = FakeViewPadding.zero;
    await tester.pump();
    expect(tester.getSize(find.byType(McTabBar)).height, 84);
  });

  testWidgets('Activity screen: every tab clears a 48dp nav bar',
      (tester) async {
    await loadAppFonts();
    configureSmallPhone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripHistoryProvider.overrideWith((ref) async => const <Trip>[]),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const HistoryScreen()),
    ));
    await tester.pumpAndSettle();

    for (final label in ['Home', 'Activity', 'Account']) {
      expectReachableWithoutScrolling(tester, find.text(label));
    }
  });
}
