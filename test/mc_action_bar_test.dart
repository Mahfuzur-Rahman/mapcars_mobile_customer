// McActionBar — the pinned footer for full-screen pages — keeps a page's
// primary action on screen whatever the content above it does: tall content,
// larger text, the keyboard up, or a 3-button nav bar under an edge-to-edge app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/theme/app_theme.dart';
import 'package:mapcars_mobile/src/core/widgets/mc.dart';

import 'support/reachability.dart';

/// The documented page shape: header, scrolling content, action bar.
///
/// [safeAreaBottom] true wraps the page in an all-sides SafeArea — the bar then
/// gets no inset from MediaQuery and must not add one of its own.
Widget _page({bool safeAreaBottom = false}) {
  final page = Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(22, 12, 22, 12),
        child: McTitle('Edit profile'),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              for (var i = 0; i < 12; i++) ...[
                McField(placeholder: 'Field $i', editable: true),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      McActionBar(children: [
        McButton('Save changes', onTap: () {}),
        McGhostButton('Cancel', onTap: () {}),
      ]),
    ],
  );
  return Scaffold(
    backgroundColor: Brand.bg,
    body: SafeArea(bottom: safeAreaBottom, child: page),
  );
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('both actions are reachable under tall content (text x$scale)',
        (tester) async {
      await pumpOnSmallPhone(tester, _page(), textScale: scale);
      expectReachableWithoutScrolling(tester, find.byType(McButton));
      expectReachableWithoutScrolling(tester, find.byType(McGhostButton));
    });
  }

  testWidgets('rides above the keyboard', (tester) async {
    await pumpOnSmallPhone(tester, _page());
    await tester.showKeyboard(find.byType(TextField).first);
    setKeyboard(tester, open: true);
    await tester.pumpAndSettle();

    expectReachableWithoutScrolling(tester, find.byType(McButton));
    expectReachableWithoutScrolling(tester, find.byType(McGhostButton));
  });

  testWidgets('paints under the nav bar and pads its buttons clear of it',
      (tester) async {
    await pumpOnSmallPhone(tester, _page());
    final bar = tester.getRect(find.byType(McActionBar));
    // Background reaches the screen edge (no strip of page showing beneath)…
    expect(bar.bottom, kSmallPhone.height);
    // …and the inset is inside it: 1 (hairline) + 12 + 54 + 10 + 54 + 12 + 48.
    expect(bar.height, 191);
  });

  testWidgets('does not add the inset again when a SafeArea already did',
      (tester) async {
    await pumpOnSmallPhone(tester, _page(safeAreaBottom: true));
    final bar = tester.getRect(find.byType(McActionBar));
    expect(bar.bottom, kSmallPhone.height - kNavBarInset);
    expect(bar.height, 143); // 1 + 12 + 54 + 10 + 54 + 12: no second inset
    expectReachableWithoutScrolling(tester, find.byType(McGhostButton));
  });

  testWidgets('a notice sits inside the bar, directly above the buttons',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      Scaffold(
        body: Column(children: [
          const Expanded(child: SizedBox()),
          McActionBar(
            notice: const McErrorBanner('Please fill in every field.'),
            children: [McButton('Create account', onTap: () {})],
          ),
        ]),
      ),
    );
    final notice = tester.getRect(find.byType(McErrorBanner));
    final button = tester.getRect(find.byType(McButton));
    final bar = tester.getRect(find.byType(McActionBar));
    expect(bar.contains(notice.topLeft) && bar.contains(notice.bottomRight),
        isTrue, reason: 'the notice is inside the bar ($notice vs $bar)');
    expect(button.top - notice.bottom, 10); // the bar's gap
    expectReachableWithoutScrolling(tester, find.byType(McErrorBanner));
    expectReachableWithoutScrolling(tester, find.byType(McButton));
  });

  // The offline message plus its "Ref:" support line is long. Uncapped, it grew
  // the bar until the button left the screen (the driver app hit 544dp at 2.0
  // text with the keyboard up). The notice is capped and scrolls inside itself;
  // the text is never truncated, because the Ref line is read by support.
  const longNotice = "Can't reach Mapcars. Please check your internet connection "
      'and try again. If this keeps happening, contact support and quote the '
      'reference below so we can find your request quickly. '
      'Ref: 7f3a9c1e-4b2d-4c58-9a6e-0d1f2b3c4d5e / net=wifi / dns=fail / '
      'api=https://gce-test.mapcars.uk / code=connectionError';

  for (final scale in [1.3, 2.0]) {
    testWidgets('a long notice with the keyboard up keeps the button reachable '
        '(text x$scale)', (tester) async {
      await loadAppFonts();
      configureSmallPhone(tester, textScale: scale);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: Brand.bg,
          body: Column(children: [
            const Padding(
                padding: EdgeInsets.all(12),
                child: McField(placeholder: 'Email', editable: true)),
            const Expanded(child: SizedBox()),
            McActionBar(
              notice: const McErrorBanner(longNotice),
              children: [McButton('Verify', onTap: () {})],
            ),
          ]),
        ),
      ));
      await tester.showKeyboard(find.byType(TextField));
      setKeyboard(tester, open: true);
      await tester.pumpAndSettle();

      expectReachableWithoutScrolling(tester, find.byType(McButton));
      final bar = tester.getRect(find.byType(McActionBar));
      final visible = visibleBottom(tester);
      expect(bar.top, greaterThan(visible * 0.3),
          reason: 'the bar must leave room for the page above it ($bar)');
      // Not truncated: the whole text is still in the tree, scrollable.
      expect(find.textContaining('Ref: 7f3a9c1e'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a notice already showing is re-capped when the keyboard opens',
      (tester) async {
    // No Scaffold here, so the page's MediaQuery carries the keyboard inset.
    await loadAppFonts();
    configureSmallPhone(tester, textScale: 2.0);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Material(
        child: Column(children: [
          const Expanded(child: SizedBox()),
          McActionBar(
            notice: McErrorBanner(List.filled(20, 'A long line of message.').join(' ')),
            children: [McButton('Verify', onTap: () {})],
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    final closed = tester.getSize(find.byType(McErrorBanner)).height;

    setKeyboard(tester, open: true);
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(McErrorBanner)).height;
    // The banner itself is taller than the cap; what is visible is the scroll
    // viewport inside the bar.
    final viewport = tester.getSize(find.descendant(
        of: find.byType(McActionBar), matching: find.byType(Scrollable))).height;
    expect(viewport, lessThanOrEqualTo(visibleBottom(tester) * 0.25 + 0.5));
    expect(open, closed); // same content, only the cap moved
  });

  testWidgets('a long notice scrolls inside the bar to its last line',
      (tester) async {
    await pumpOnSmallPhone(
      tester,
      Scaffold(
        body: Column(children: [
          const Expanded(child: SizedBox()),
          McActionBar(
            notice: McErrorBanner(List.filled(14, 'Line of the message.').join(' ')),
            children: [McButton('Verify', onTap: () {})],
          ),
        ]),
      ),
      textScale: 1.3,
    );
    final scrollable = find.descendant(
        of: find.byType(McActionBar), matching: find.byType(Scrollable));
    expect(scrollable, findsOneWidget);
    await tester.drag(scrollable, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(McErrorBanner)).bottom,
        lessThan(tester.getRect(find.byType(McButton)).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('holds at most two buttons', (tester) async {
    // A third stacked full-width button eats most of a small screen; the spec
    // caps a pinned footer at two.
    await pumpOnSmallPhone(
      tester,
      Scaffold(
        body: McActionBar(children: [
          McButton('A', onTap: () {}),
          McButton('B', onTap: () {}),
          McButton('C', onTap: () {}),
        ]),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}
