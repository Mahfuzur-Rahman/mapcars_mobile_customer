// McSheet — the rounded sheet over every ride-flow map, and the body of every
// modal sheet — must keep its actions tappable on a small phone with a 3-button
// nav bar, at normal and larger text.
//
// It used to pad its bottom with a fixed 28dp. Android 15+ draws the app under
// the 48dp nav bar, so the last ~20dp of whatever sat at the bottom of the sheet
// was under the bar and its taps went to the system. It also took a fixed
// height with non-scrolling content, so larger text pushed the last button out
// of the sheet altogether.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/widgets/mc.dart';

import 'support/reachability.dart';

/// The shape every map screen uses: a full-bleed map with the sheet aligned to
/// the bottom of a Stack.
Widget _mapScreen(Widget sheet) => Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Brand.bg)),
          Align(alignment: Alignment.bottomCenter, child: sheet),
        ],
      ),
    );

/// Far more content than fits: the sheet's body has to scroll.
Widget _tallBody() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 20; i++)
          SizedBox(height: 44, child: Text('Option $i')),
      ],
    );

void main() {
  testWidgets(
      'a sheet without a footer keeps its last child clear of the nav bar',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const McTitle('Where to?'),
            const SizedBox(height: 12),
            McGhostButton('Last action', onTap: () {}),
          ],
        ),
      )),
    );

    final last = find.byType(McGhostButton);
    expect(kSmallPhone.height - tester.getRect(last).bottom,
        greaterThanOrEqualTo(kNavBarInset));
    expectReachableWithoutScrolling(tester, last);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets(
        'a footer stays on screen when the body overflows (text x$scale)',
        (tester) async {
      await pumpOnSmallPhone(
        tester,
        _mapScreen(McSheet(
          footer: McButton('Book now', onTap: () {}),
          child: _tallBody(),
        )),
        textScale: scale,
      );

      expectReachableWithoutScrolling(tester, find.byType(McButton));
      // The body took the overflow instead, and scrolls.
      final body = tester.state<ScrollableState>(find.descendant(
          of: find.byType(McSheet), matching: find.byType(Scrollable)));
      expect(body.position.maxScrollExtent, greaterThan(0));
    });
  }

  testWidgets('sizes to its content, under maxHeight', (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(const McSheet(maxHeight: 400, child: Text('Short'))),
    );
    expect(tester.getSize(find.byType(McSheet)).height, lessThan(400));
  });

  testWidgets('never grows past maxHeight; the body scrolls instead',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(maxHeight: 300, child: _tallBody())),
    );
    expect(tester.getSize(find.byType(McSheet)).height, 300);
  });

  testWidgets('an explicit maxHeight is held to the 85% share too',
      (tester) async {
    // Callers pick maxHeight for a typical phone. On a short one it must not
    // outgrow the 85% share, or the floating back button (top ~58) is covered.
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(maxHeight: 700, child: _tallBody())),
    );
    expect(tester.getSize(find.byType(McSheet)).height,
        closeTo(kSmallPhone.height * 0.85, 0.5));
  });

  testWidgets('with no maxHeight, caps at 85% of the available height',
      (tester) async {
    await pumpOnSmallPhone(tester, _mapScreen(McSheet(child: _tallBody())));
    expect(tester.getSize(find.byType(McSheet)).height,
        closeTo(kSmallPhone.height * 0.85, 0.5));
  });

  testWidgets('keeps the original 28dp bottom padding when there is no inset',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      _mapScreen(const McSheet(child: SizedBox(key: Key('body'), height: 40))),
    );
    tester.view
      ..padding = FakeViewPadding.zero
      ..viewPadding = FakeViewPadding.zero;
    await tester.pump();

    final body = tester.getRect(find.byKey(const Key('body')));
    expect(kSmallPhone.height - body.bottom, 28);
  });

  testWidgets('scrollController drives the body scroll view', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpOnSmallPhone(
      tester,
      _mapScreen(McSheet(scrollController: controller, child: _tallBody())),
    );

    expect(controller.hasClients, isTrue);
    controller.jumpTo(100);
    await tester.pump();
    expect(controller.offset, 100);
  });
}
