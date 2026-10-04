// McActionBar — the pinned footer for full-screen pages — keeps a page's
// primary action on screen whatever the content above it does: tall content,
// larger text, the keyboard up, or a 3-button nav bar under an edge-to-edge app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
