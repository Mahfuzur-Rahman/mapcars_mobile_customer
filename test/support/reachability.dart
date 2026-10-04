// "Can the customer tap it without scrolling?" — the shared test harness.
//
// Client report: bottom buttons were sometimes hard to tap or needed a scroll
// to find. Both causes only show on real hardware, never on a default test
// surface: Android 15+ forces edge-to-edge (and iOS has the home indicator), so
// the bottom of the screen belongs to the system bar; and a small phone with
// larger text, or with the keyboard up, pushes a trailing button off-screen.
// These helpers recreate those conditions so a widget test can catch both.
//
// Usage:
//
//   await pumpOnSmallPhone(tester, const MyScreen(), textScale: 1.3);
//   expectReachableWithoutScrolling(
//       tester, find.widgetWithText(McButton, 'Save'));
//
// Screens that need their own app shell (a ProviderScope, a router) load the
// real font, call [configureSmallPhone] and pump themselves — with
// `theme: AppTheme.light`, or the font never applies:
//
//   await loadAppFonts();
//   configureSmallPhone(tester);
//   await tester.pumpWidget(ProviderScope(child: MaterialApp(home: ...)));
//
// The keyboard is opened after the screen is up, the way it happens on a
// device: focus a field first, then report the insets —
//
//   await tester.showKeyboard(find.byType(TextField).first);
//   setKeyboard(tester, open: true);
//   await tester.pumpAndSettle();
//
// Setting insets without a focused field is the weak pattern: the screen
// reacts to a keyboard no field asked for, and a test can pass while the real
// order of events (a field takes focus, then the keyboard arrives) is broken.
// Prefer finding the whole button (`McButton`) over its label — a label can
// clear the bar while the button is half under it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/theme/app_theme.dart';

/// A small Android phone, in logical pixels.
const Size kSmallPhone = Size(360, 640);

/// A 3-button navigation bar — the tallest common bottom system inset.
const double kNavBarInset = 48;

/// A typical soft keyboard.
const double kKeyboardInset = 300;

/// Puts the test view into the small-phone configuration for the rest of the
/// test (reset automatically on tear-down).
///
/// The nav-bar inset is set on both `padding` and `viewPadding`, with the
/// keyboard closed. To open it, see [setKeyboard]: with it up the view reports
/// what Android does under `adjustResize` — `viewInsets.bottom` is the
/// keyboard, `padding.bottom` drops to 0 (the keyboard covers the nav bar), and
/// `viewPadding.bottom` stays 48 because the bar is still physically there.
void configureSmallPhone(
  WidgetTester tester, {
  double textScale = 1.0,
}) {
  final view = tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = kSmallPhone
    ..viewPadding = const FakeViewPadding(bottom: kNavBarInset)
    ..padding = const FakeViewPadding(bottom: kNavBarInset)
    ..viewInsets = FakeViewPadding.zero;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Opens (or closes) the keyboard on an already-configured small phone, the way
/// it happens on a device: after the screen is up, when a field takes focus.
/// Focus a field first (`tester.showKeyboard(field)`), then call this — insets
/// with no focused field are not what a device reports.
void setKeyboard(WidgetTester tester, {required bool open}) {
  tester.view
    ..padding = FakeViewPadding(bottom: open ? 0 : kNavBarInset)
    ..viewInsets = FakeViewPadding(bottom: open ? kKeyboardInset : 0);
}

/// Pumps [home] in a themed `MaterialApp` on the small phone.
///
/// Loads the app's real font first: the default test font draws every glyph a
/// full em wide, which wraps text far more than Nunito does and would make a
/// layout test fail on line breaks no customer ever sees.
Future<void> pumpOnSmallPhone(
  WidgetTester tester,
  Widget home, {
  double textScale = 1.0,
}) async {
  await loadAppFonts();
  configureSmallPhone(tester, textScale: textScale);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: home,
  ));
  await tester.pump();
}

// A flag, not a cached Future: each testWidgets body runs in its own fake-async
// zone, and awaiting a Future completed in an earlier test's zone never
// resumes — the next test just hangs.
bool _fontsLoaded = false;

/// Registers the bundled Nunito font with the test engine. Idempotent.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  final loader = FontLoader(AppTheme.fontFamily)
    ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
  await loader.load();
  _fontsLoaded = true;
}

/// The lowest y a customer can see and touch: above the system bar, and above
/// the keyboard when it is up.
///
/// The keyboard inset already spans the nav bar beneath it, so the two are not
/// summed — the larger one is the edge.
double visibleBottom(WidgetTester tester) {
  final view = tester.view;
  final dpr = view.devicePixelRatio;
  final height = view.physicalSize.height / dpr;
  final systemBar = view.viewPadding.bottom / dpr;
  final keyboard = view.viewInsets.bottom / dpr;
  return height - math.max(systemBar, keyboard);
}

/// Asserts that [finder]'s widget is on screen, fully clear of the system bar
/// and the keyboard, and actually receives a tap at its centre — with no
/// scrolling performed first.
void expectReachableWithoutScrolling(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  final bottom = visibleBottom(tester);
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  const slack = 0.5; // sub-pixel layout rounding

  expect(rect.top, greaterThanOrEqualTo(-slack),
      reason: '$finder starts above the top of the screen ($rect)');
  expect(rect.left >= -slack && rect.right <= width + slack, isTrue,
      reason: '$finder runs off the side of the screen ($rect)');
  expect(rect.bottom, lessThanOrEqualTo(bottom + slack),
      reason: '$finder ends at y=${rect.bottom.toStringAsFixed(1)}, but '
          'everything below y=${bottom.toStringAsFixed(1)} is under the '
          'system bar or the keyboard ($rect)');
  expect(finder.hitTestable(), findsOneWidget,
      reason: '$finder is on screen but something else takes the tap');
}
