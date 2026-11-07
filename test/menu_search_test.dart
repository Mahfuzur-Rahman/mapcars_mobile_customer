// The menu drawer's search box: what it finds, in what order, and — in a real
// (non-debug) build — that it can never surface a prototype walk-through step.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/router/app_router.dart';
import 'package:mapcars_mobile/src/core/theme/app_theme.dart';
import 'package:mapcars_mobile/src/core/widgets/menu_search.dart';
import 'package:mapcars_mobile/src/core/widgets/screen_stepper.dart';

const _routes = [
  StepRoute('/a', 'Payment', icon: 'card', keywords: ['card']),
  StepRoute('/b', 'Trip history', icon: 'clock', keywords: ['receipt', 'payment slips']),
  StepRoute('/c', 'Account', icon: 'user', keywords: ['help']),
];

List<String> _paths(List<MenuHit> hits) => [for (final h in hits) h.route.path];

/// What a release build's search box looks through.
final _releasePool = kCustomerFlow.where((r) => r.isSearchable).toList();

void main() {
  test('an empty query finds nothing, so the plain menu shows', () {
    expect(searchMenu(_routes, ''), isEmpty);
    expect(searchMenu(_routes, '   '), isEmpty);
  });

  test('a label match outranks a keyword match, case-insensitively', () {
    expect(_paths(searchMenu(_routes, 'PAY')), ['/a', '/b']);
  });

  test('a word inside the label matches', () {
    expect(_paths(searchMenu(_routes, 'hist')), ['/b']);
  });

  test('a keyword match says which keyword found it', () {
    final hits = searchMenu(_routes, 'help');
    expect(_paths(hits), ['/c']);
    expect(hits.single.matchedKeyword, 'help');
  });

  test('route paths only match in the dev walk-through', () {
    expect(searchMenu(_routes, '/c'), isEmpty);
    expect(_paths(searchMenu(_routes, '/c', matchPath: true)), ['/c']);
  });

  group('release build', () {
    test('menu shows the user destinations, including Edit profile and Change password', () {
      expect(
        [for (final r in kCustomerFlow.where((r) => r.isMenuItem)) r.label],
        ['Home', 'Messages', 'Trip history', 'Payment', 'Saved places', 'Account',
         'Edit profile',
         'Change password'],
      );
    });

    test('search never reaches a prototype step', () {
      for (final q in ['search', 'tracking', 'confirm', 'rate', 'screens', 'otp']) {
        for (final hit in searchMenu(_releasePool, q)) {
          expect(hit.route.icon, isNotNull, reason: '"$q" found ${hit.route.path}');
        }
      }
      expect(searchMenu(_releasePool, 'searching'), isEmpty);
    });

    test('everyday words land on the right page', () {
      expect(searchMenu(_releasePool, 'password').first.route.path,
          '/account/change-password');
      expect(searchMenu(_releasePool, 'card').first.route.path, '/payment');
      expect(searchMenu(_releasePool, 'receipt').first.route.path, '/activity');
      expect(searchMenu(_releasePool, 'help').first.route.path, '/account');
      expect(searchMenu(_releasePool, 'email').first.route.path, '/account/edit');
    });
  });

  testWidgets('typing filters the drawer, explains keyword hits, and clears',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(devDrawerOpenProvider.notifier).state = true;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ScreenStepper(
          routes: _routes,
          current: '/a',
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'help');
    await tester.pump();
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Payment'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Nothing matches “zzz”'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Trip history'), findsOneWidget);

    // Closing the drawer resets the search for next time.
    await tester.enterText(find.byType(TextField), 'help');
    container.read(devDrawerOpenProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.text('help'), findsNothing);
  });
}
