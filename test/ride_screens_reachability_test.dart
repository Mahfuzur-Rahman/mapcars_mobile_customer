// The ride-flow screens' primary actions must be tappable without scrolling on a
// small phone (360x640) with a 3-button nav bar (48dp), at normal and larger text.
//
// Each of these screens used to end its sheet with the action — "Confirm MAP
// CARS", "Cancel request", "Cancel ride", "Confirm this location" — as the last
// child of a scrolling body (or, for pick-on-map, a card with a fixed 32dp
// bottom padding). With the nav bar drawn over the bottom 48dp, or with larger
// text pushing the content down, the button was under the bar or off the end of
// the scroll. They now live in `McSheet(footer: ...)`, pinned below a body that
// scrolls instead.
//
// The maps are replaced by a flat box (see support/fake_google_maps.dart): this
// file tests layout, not Google's SDK. Everything else is the real screen,
// running on the real font.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapcars_mobile/src/core/storage/prefs.dart';
import 'package:mapcars_mobile/src/core/theme/app_theme.dart';
import 'package:mapcars_mobile/src/core/widgets/countdown.dart';
import 'package:mapcars_mobile/src/core/widgets/mc.dart';
import 'package:mapcars_mobile/src/features/ride/models/chat_message.dart';
import 'package:mapcars_mobile/src/features/ride/models/driver_location.dart';
import 'package:mapcars_mobile/src/features/ride/models/payment_settings.dart';
import 'package:mapcars_mobile/src/features/ride/models/place.dart';
import 'package:mapcars_mobile/src/features/ride/models/place_prediction.dart';
import 'package:mapcars_mobile/src/features/ride/models/ride_option.dart';
import 'package:mapcars_mobile/src/features/ride/models/ride_quote.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/choose_ride_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/confirm_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/home_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/in_progress_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/pick_on_map_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/route_preview_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/searching_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/tracking_screen.dart';
import 'package:mapcars_mobile/src/features/ride/providers/payment_settings_provider.dart';
import 'package:mapcars_mobile/src/features/ride/providers/ride_flow_notifier.dart';
import 'package:mapcars_mobile/src/features/ride/providers/search_history_provider.dart';
import 'package:mapcars_mobile/src/features/ride/services/maps_service.dart';
import 'package:mapcars_mobile/src/features/ride/services/nearby_drivers_service.dart';
import 'package:mapcars_mobile/src/features/ride/services/ride_service.dart';
import 'package:mapcars_mobile/src/features/ride/services/search_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_google_maps.dart';
import 'support/reachability.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

const _pickup = Place(
    label: 'Current location', address: '', lat: 51.5308, lng: -0.1238);
const _dropoff = Place(
    label: 'Heathrow Terminal 5',
    address: 'Wallis Rd, Longford, Hounslow TW6 2GA',
    lat: 51.4700,
    lng: -0.4543);

Trip _trip(
  String status, {
  bool withDriver = true,
  String? pin = '4821',
  DateTime? expiresAt,
  bool canExtend = true,
}) =>
    Trip.fromJson({
      'id': 'trip-1',
      'status': status,
      'pickup': _pickup.toJson(),
      'dropoff': _dropoff.toJson(),
      'tier': 'economy',
      'farePence': 3450,
      'pin': pin,
      if (withDriver)
        'driver': {
          'name': 'Christopher Wellington',
          'rating': 4.9,
          'vehicle': 'Silver Toyota Prius · Economy',
          'plate': 'LB12 KXR',
          'phone': '+447700900123',
        },
      if (expiresAt != null) 'expiresAtUtc': expiresAt.toIso8601String(),
      'canExtend': canExtend,
    });

/// Four tiers, the size of today's live fare chart.
const _tiers = [
  RideOption(
      id: 'economy',
      tier: 'economy',
      name: 'Economy',
      etaMinutes: 3,
      pricePence: 3450,
      description: 'Everyday rides',
      icon: 'car'),
  RideOption(
      id: 'comfort',
      tier: 'comfort',
      name: 'Comfort',
      etaMinutes: 4,
      pricePence: 4150,
      description: 'Newer cars, extra legroom',
      icon: 'car'),
  RideOption(
      id: 'xl',
      tier: 'xl',
      name: 'XL',
      etaMinutes: 6,
      pricePence: 5200,
      description: 'Up to 6 passengers',
      icon: 'car'),
  RideOption(
      id: 'premium',
      tier: 'premium',
      name: 'Premium',
      etaMinutes: 8,
      pricePence: 6900,
      description: 'Top-rated drivers',
      icon: 'bolt'),
];

const _quote =
    RideQuote(distanceMiles: 17.4, etaMinutes: 38, options: _tiers);

/// A repository that answers every call the screens make on mount, with nothing.
class _FakeRepo implements RideRepository {
  @override
  Future<DriverLocation?> driverLocation(String tripId) async => null;
  @override
  Future<Trip?> getActiveTrip() async => null;
  @override
  Future<Trip> getTrip(String id) => throw UnimplementedError();
  @override
  Future<Trip> requestTrip({
    required Place pickup,
    required Place dropoff,
    required String rideOptionId,
    required double distanceMiles,
    required int durationMinutes,
    String? promoCode,
    String? paymentMethod,
    String? paymentMethodId,
    double tipAmount = 0,
  }) =>
      throw UnimplementedError();
  @override
  Future<Trip> cancelTrip(String id, {String? reason}) =>
      throw UnimplementedError();
  @override
  Future<Trip> extendTrip(String id) => throw UnimplementedError();
  @override
  Future<List<ChatMessage>> getMessages(String tripId) async => const [];
  @override
  Future<ChatMessage> sendMessage(String tripId, {required String content}) =>
      throw UnimplementedError();
  @override
  Future<void> submitRating(String tripId,
      {required int score, String? comment}) async {}
  @override
  Future<List<Trip>> tripHistory() async => const [];
}

/// Six tiers: a fare chart longer than today's four.
const _sixTierQuote = RideQuote(distanceMiles: 17.4, etaMinutes: 38, options: [
  ..._tiers,
  RideOption(
      id: 'executive',
      tier: 'executive',
      name: 'Executive',
      etaMinutes: 9,
      pricePence: 8400,
      description: 'Business class',
      icon: 'bolt'),
  RideOption(
      id: 'van',
      tier: 'van',
      name: 'Van',
      etaMinutes: 11,
      pricePence: 9100,
      description: 'Luggage and groups',
      icon: 'car'),
]);

class _FakeMaps extends GoogleMapsService {
  @override
  Future<List<PlacePrediction>> autocomplete(String query,
          {LatLng? origin}) async =>
      const [];

  @override
  Future<Place> reverseGeocode(LatLng latLng) async => const Place(
      label: '221B Baker Street',
      address: '221B Baker St, London NW1 6XE, United Kingdom',
      lat: 51.5238,
      lng: -0.1586);
}

/// The whole button, not just its label: a button half under the nav bar is
/// what the customer actually sees, even when its text happens to clear it.
Finder _button(String label, {bool contains = false}) => find.ancestor(
      of: contains ? find.textContaining(label) : find.text(label),
      matching: find.byWidgetPredicate((w) => w is McButton || w is McGhostButton),
    );

ProviderContainer? _container;

/// Pumps [screen] on the small phone inside the real app theme, with the ride
/// flow already holding a route and a chosen tier (what `RouteGate` guarantees
/// in the app).
Future<FakeGoogleMapsPlatform> _pump(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1.0,
  Future<RideQuote> Function()? quote,
  Size? size,
}) async {
  await loadAppFonts();
  configureSmallPhone(tester, textScale: textScale);
  if (size != null) tester.view.physicalSize = size;
  final maps = installFakeGoogleMaps();
  mockGeolocatorUnavailable(tester);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(overrides: [
    rideRepositoryProvider.overrideWithValue(_FakeRepo()),
    googleMapsServiceProvider.overrideWithValue(_FakeMaps()),
    nearbyDriversServiceProvider
        .overrideWithValue(NearbyDriversService(Dio())),
    sharedPreferencesProvider.overrideWithValue(prefs),
    // The search countdown's once-a-second ticker would leave a live timer
    // behind; layout doesn't need it to tick.
    secondTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
    searchHistoryProvider.overrideWith(
        (ref) => SearchHistoryNotifier(SearchHistoryService(prefs), null)),
    rideQuoteProvider
        .overrideWith((ref) => quote != null ? quote() : Future.value(_quote)),
    paymentSettingsProvider.overrideWith((ref) async => const PaymentSettings(
        cashEnabled: true, cardEnabled: true, defaultMethod: 'card')),
  ]);
  _container = container;
  addTearDown(() => _container?.dispose());

  container.read(rideFlowProvider.notifier)
    ..setRoute(
        pickup: _pickup,
        dropoff: _dropoff,
        distanceMiles: 17.4,
        durationMinutes: 38)
    ..selectOption('economy');

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: screen,
    ),
  ));
  // Let the providers' futures resolve and the map report itself created.
  await tester.pump();
  await tester.pump();
  return maps;
}

/// Scrolls the sheet's body to its very end, as a customer does to reach the
/// last row of a long list. A pinned footer must still be on screen after it.
Future<void> _scrollSheetToEnd(WidgetTester tester) async {
  final body = tester.state<ScrollableState>(find
      .descendant(of: find.byType(McSheet), matching: find.byType(Scrollable))
      .first);
  body.position.jumpTo(body.position.maxScrollExtent);
  await tester.pump();
}

/// Tears the screen down inside the test, so tickers and timers it started are
/// cancelled before the framework checks for stragglers.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // The providers too: an autoDispose stream (the search countdown) is only
  // cancelled once its container goes, and a live timer fails the test.
  _container?.dispose();
  _container = null;
}

void main() {
  for (final scale in [1.0, 1.3]) {
    group('text x$scale', () {
      testWidgets('confirm: "Confirm MAP CARS" is on screen', (tester) async {
        await _pump(tester, const ConfirmScreen(), textScale: scale);

        expectReachableWithoutScrolling(
            tester, _button('Confirm MAP CARS'));
        await _unmount(tester);
      });

      testWidgets('searching: "Cancel request" is on screen', (tester) async {
        await _pump(
          tester,
          SearchingScreen(
              trip: _trip('Requested',
                  withDriver: false,
                  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 4)))),
          textScale: scale,
        );

        expectReachableWithoutScrolling(tester, _button('Cancel request'));
        await _unmount(tester);
      });

      testWidgets(
          'searching, window lapsed: "Keep searching" and "Cancel ride" are on screen',
          (tester) async {
        await _pump(
          tester,
          SearchingScreen(
              trip: _trip('Requested',
                  withDriver: false,
                  expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 10)))),
          textScale: scale,
        );

        expectReachableWithoutScrolling(tester, _button('Keep searching'));
        expectReachableWithoutScrolling(tester, _button('Cancel ride'));
        await _unmount(tester);
      });

      for (final status in ['DriverAssigned', 'DriverArrived']) {
        testWidgets('tracking ($status): "Cancel ride" is on screen',
            (tester) async {
          await _pump(tester, TrackingScreen(trip: _trip(status)),
              textScale: scale);

          expectReachableWithoutScrolling(tester, _button('Cancel ride'));
          // The contact shortcuts stay with the driver card, in the body.
          expect(find.text('Call'), findsOneWidget);
          expect(find.text('Message'), findsOneWidget);
          expect(find.text('Safety'), findsOneWidget);
          await _unmount(tester);
        });
      }

      testWidgets('pick on map: "Confirm this location" is on screen',
          (tester) async {
        await _pump(
          tester,
          const PickOnMapScreen(initialPosition: LatLng(51.5238, -0.1586)),
          textScale: scale,
        );

        expectReachableWithoutScrolling(
            tester, _button('Confirm this location'));
        await _unmount(tester);
      });

      testWidgets('choose ride: the choose button is on screen',
          (tester) async {
        await _pump(tester, const ChooseRideScreen(), textScale: scale);
        await _scrollSheetToEnd(tester);

        expectReachableWithoutScrolling(
            tester, _button('Choose Economy', contains: true));
        await _unmount(tester);
      });
    });
  }

  // A large font setting (Android goes to 2.0; see the report for what overflows
  // there regardless of this change). The body can't fit, so it has to scroll —
  // and the action must not be what scrolls away.
  group('text x1.6 (large font setting)', () {
    testWidgets('confirm: the body scrolls, the button stays', (tester) async {
      await _pump(tester, const ConfirmScreen(), textScale: 1.6);

      expectReachableWithoutScrolling(tester, _button('Confirm MAP CARS'));
      await _unmount(tester);
    });

    testWidgets('searching, window lapsed: both buttons stay', (tester) async {
      await _pump(
        tester,
        SearchingScreen(
            trip: _trip('Requested',
                withDriver: false,
                expiresAt:
                    DateTime.now().toUtc().subtract(const Duration(seconds: 10)))),
        textScale: 1.6,
      );

      expectReachableWithoutScrolling(tester, _button('Keep searching'));
      expectReachableWithoutScrolling(tester, _button('Cancel ride'));
      await _unmount(tester);
    });

    testWidgets('tracking: "Cancel ride" stays', (tester) async {
      await _pump(tester, TrackingScreen(trip: _trip('DriverAssigned')),
          textScale: 1.6);

      expectReachableWithoutScrolling(tester, _button('Cancel ride'));
      await _unmount(tester);
    });
  });

  testWidgets('pick on map: stays reachable with the keyboard up',
      (tester) async {
    await _pump(
      tester,
      const PickOnMapScreen(initialPosition: LatLng(51.5238, -0.1586)),
    );
    await tester.showKeyboard(find.byType(TextField));
    setKeyboard(tester, open: true);
    await tester.pumpAndSettle();

    expectReachableWithoutScrolling(
        tester, _button('Confirm this location'));
    await _unmount(tester);
  });

  testWidgets('pick on map: the GPS button sits above the card, not under it',
      (tester) async {
    await _pump(
      tester,
      const PickOnMapScreen(initialPosition: LatLng(51.5238, -0.1586)),
    );

    final fab = find.byType(FloatingActionButton);
    expectReachableWithoutScrolling(tester, fab);
    expect(tester.getRect(fab).bottom,
        lessThanOrEqualTo(tester.getRect(_button('Confirm this location')).top));
    await _unmount(tester);
  });

  testWidgets(
      'pick on map: while searching, the GPS button gives way to the clear (x) button',
      (tester) async {
    // With the keyboard up the search bar and the GPS button are in the same
    // corner of the screen; the GPS button sat over the search bar's clear
    // button, so tapping x re-centred the map instead of clearing the search.
    await _pump(
      tester,
      const PickOnMapScreen(initialPosition: LatLng(51.5238, -0.1586)),
    );
    await tester.enterText(find.byType(TextField), 'baker');
    setKeyboard(tester, open: true);
    await tester.pump(const Duration(milliseconds: 400)); // search debounce
    await tester.pumpAndSettle();

    final clear = find.byIcon(Icons.close_rounded);
    expect(clear, findsOneWidget);
    expect(clear.hitTestable(), findsOneWidget,
        reason: 'something (the GPS button?) covers the clear button');
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(clear);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');

    // Once the search is done the GPS button is back.
    FocusManager.instance.primaryFocus?.unfocus();
    setKeyboard(tester, open: false);
    await tester.pumpAndSettle();
    expectReachableWithoutScrolling(tester, find.byType(FloatingActionButton));
    await _unmount(tester);
  });

  group('in progress', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('has no "Cancel ride" — the API refuses it mid-trip (text x$scale)',
          (tester) async {
        await _pump(tester, InProgressScreen(trip: _trip('InProgress')),
            textScale: scale);

        expect(find.text('Cancel ride'), findsNothing);
        // Everything else the sheet offers is still there.
        expect(find.text('Safety'), findsOneWidget);
        expect(find.text('Share trip'), findsOneWidget);
        expect(find.text('Message driver'), findsOneWidget);
        await _unmount(tester);
      });
    }

    testWidgets('Safety, Share trip and Message driver are on screen',
        (tester) async {
      await _pump(tester, InProgressScreen(trip: _trip('InProgress')));

      expectReachableWithoutScrolling(tester, _button('Safety'));
      expectReachableWithoutScrolling(tester, _button('Share trip'));
      expectReachableWithoutScrolling(tester, _button('Message driver'));
      await _unmount(tester);
    });
  });

  group('tracking PIN', () {
    // The customer reads this out to the driver at pickup, so the whole card
    // must be on screen without scrolling the sheet — before the driver arrives
    // as well as after. Below the driver card it was half under the fold.
    for (final scale in [1.0, 1.3]) {
      for (final status in ['DriverAssigned', 'DriverArrived']) {
        testWidgets('$status, text x$scale: the whole PIN card is visible',
            (tester) async {
          await _pump(tester, TrackingScreen(trip: _trip(status)),
              textScale: scale);

          final card = find
              .ancestor(of: find.textContaining('PIN'), matching: find.byType(McCard))
              .first;
          final body = tester.getRect(find
              .descendant(of: find.byType(McSheet), matching: find.byType(Scrollable))
              .first);
          final rect = tester.getRect(card);
          expect(rect.top, greaterThanOrEqualTo(body.top - 0.5),
              reason: 'PIN card $rect starts above the sheet body $body');
          expect(rect.bottom, lessThanOrEqualTo(body.bottom + 0.5),
              reason: 'PIN card $rect runs past the end of the sheet body $body');
          // And its digits are what the customer sees, not clipped.
          for (final digit in '4821'.split('')) {
            expect(find.text(digit), findsWidgets);
          }
          await _unmount(tester);
        });
      }
    }
  });

  group('re-centre pill', () {
    // After the customer pans the map away, "Show route" brings the driver and
    // the destination back into frame. It sat at the bottom of the full screen,
    // i.e. under the sheet, so it could be seen on no phone at all. Lifted over
    // the sheet it then collided with the controls at the top of the screen
    // (status pill, and at large text the Home / Menu buttons) and took their
    // taps. It must sit between the two, touching neither.
    Future<void> expectPillClear(WidgetTester tester, String statusText) async {
      final pill = find
          .ancestor(
              of: find.text('Show route'), matching: find.byType(Container))
          .first;
      final status = find
          .ancestor(
              of: find.textContaining(statusText),
              matching: find.byType(Container))
          .first;
      final pillRect = tester.getRect(pill);
      final sheetRect = tester.getRect(find.byType(McSheet));

      expectReachableWithoutScrolling(tester, find.text('Show route'));
      expect(pillRect.top, greaterThanOrEqualTo(0), reason: 'pill $pillRect');

      final others = <String, Rect>{
        'McFloatingNav': tester.getRect(find.byType(McFloatingNav)),
        'status pill': tester.getRect(status),
        for (var i = 0; i < find.byType(McCircleButton).evaluate().length; i++)
          'McCircleButton #$i':
              tester.getRect(find.byType(McCircleButton).at(i)),
      };
      others.forEach((name, rect) {
        expect(pillRect.overlaps(rect), isFalse,
            reason: 'pill $pillRect overlaps $name $rect');
      });
      // And the sheet leaves the status line readable.
      expect(sheetRect.top,
          greaterThanOrEqualTo(tester.getRect(status).bottom - 0.5),
          reason: 'sheet $sheetRect covers the status pill');

      // Home and Menu still take the tap rather than the pill.
      for (final icon in ['home', 'menu']) {
        expect(
            find
                .byWidgetPredicate(
                    (w) => w is McCircleButton && w.icon == icon)
                .hitTestable(),
            findsOneWidget,
            reason: '$icon is covered');
      }
    }

    testWidgets(
        'tracking, tiny screen (360x480, text x1.6): the docked pill still clears the top controls and takes taps',
        (tester) async {
      // Too short for the sheet to leave a strip above it: the pill docks onto
      // the sheet's top edge — painted over the sheet, not under it.
      final maps = await _pump(
          tester, TrackingScreen(trip: _trip('DriverAssigned')),
          textScale: 1.6, size: const Size(360, 480));
      maps.moveStarted();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final pill = tester.getRect(find
          .ancestor(of: find.text('Show route'), matching: find.byType(Container))
          .first);
      final status = tester.getRect(find
          .ancestor(
              of: find.textContaining('Your driver is on the way'),
              matching: find.byType(Container))
          .first);
      expect(pill.overlaps(status), isFalse, reason: 'pill $pill over status $status');
      expect(pill.overlaps(tester.getRect(find.byType(McFloatingNav))), isFalse);
      expectReachableWithoutScrolling(tester, find.text('Show route'));
      // Tap the pill's lower edge: that is the part that overlaps the sheet,
      // so only a pill painted above the sheet gets the tap.
      expect(pill.bottom, greaterThan(tester.getRect(find.byType(McSheet)).top),
          reason: 'this screen is meant to force the docked case');
      await tester.tapAt(Offset(pill.center.dx, pill.bottom - 2));
      await tester.pump();
      expect(find.text('Show route'), findsNothing);
      await _unmount(tester);
    });

    for (final scale in [1.0, 1.3, 1.6]) {
      for (final status in ['DriverAssigned', 'DriverArrived']) {
        testWidgets('tracking ($status, text x$scale): clear of the top controls',
            (tester) async {
          final maps = await _pump(tester, TrackingScreen(trip: _trip(status)),
              textScale: scale);
          expect(find.text('Show route'), findsNothing);

          maps.moveStarted();
          await tester.pump(); // the event
          await tester.pump(); // the measured heights, after layout
          await tester.pump();

          await expectPillClear(
              tester,
              status == 'DriverArrived'
                  ? 'Your driver has arrived'
                  : 'Your driver is on the way');
          // The sheet still has its pinned button on screen.
          expectReachableWithoutScrolling(tester, _button('Cancel ride'));

          // Tapping it puts the map back to following the driver.
          await tester.tap(find.text('Show route'));
          await tester.pump();
          expect(find.text('Show route'), findsNothing);
          await _unmount(tester);
        });
      }

      testWidgets('in progress (text x$scale): clear of the top controls',
          (tester) async {
        final maps = await _pump(
            tester, InProgressScreen(trip: _trip('InProgress')),
            textScale: scale);

        maps.moveStarted();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await expectPillClear(tester, 'On trip');
        await _unmount(tester);
      });
    }
  });

  group('choose ride sheet', () {
    // The button is the footer: scroll the list to its last row, and it is
    // still on screen. (In the body it scrolled out of view with the first rows.)
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('the choose button is on screen, 4 tiers (text x$scale)',
          (tester) async {
        await _pump(tester, const ChooseRideScreen(), textScale: scale);
        await _scrollSheetToEnd(tester);

        expectReachableWithoutScrolling(
            tester, _button('Choose Economy', contains: true));
        await _unmount(tester);
      });
    }

    testWidgets('the choose button is on screen, 6 tiers (text x1.3)',
        (tester) async {
      await _pump(tester, const ChooseRideScreen(),
          textScale: 1.3, quote: () => Future.value(_sixTierQuote));
      await _scrollSheetToEnd(tester);

      expectReachableWithoutScrolling(
          tester, _button('Choose Economy', contains: true));
      await _unmount(tester);
    });

    testWidgets('selecting another tier updates the pinned button',
        (tester) async {
      await _pump(tester, const ChooseRideScreen(), textScale: 1.3);

      await tester.tap(find.text('Comfort'));
      await tester.pump();
      expectReachableWithoutScrolling(
          tester, _button('Choose Comfort', contains: true));
      await _unmount(tester);
    });

    testWidgets('all four tiers fit without scrolling (text x1.0)',
        (tester) async {
      await _pump(tester, const ChooseRideScreen());

      for (final tier in ['Economy', 'Comfort', 'XL', 'Premium']) {
        expectReachableWithoutScrolling(tester, find.text(tier));
      }
      // The last row's price, at the bottom right of the sheet's content.
      expectReachableWithoutScrolling(tester, find.text('£69.00'));
      await _unmount(tester);
    });

    testWidgets('loading, error and priced states are the same height',
        (tester) async {
      final pending = Completer<RideQuote>();
      await _pump(tester, const ChooseRideScreen(), quote: () => pending.future);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final loading = tester.getSize(find.byType(McSheet)).height;

      pending.complete(_quote);
      await tester.pump();
      await tester.pump();
      final priced = tester.getSize(find.byType(McSheet)).height;
      expect(loading, closeTo(priced, 1),
          reason: 'loading sheet $loading dp vs priced sheet $priced dp');
      await _unmount(tester);

      await _pump(tester, const ChooseRideScreen(),
          quote: () => Future<RideQuote>.error(StateError('no chart')));
      await tester.pump();
      expectReachableWithoutScrolling(tester, _button('Retry'));
      final errored = tester.getSize(find.byType(McSheet)).height;
      expect(errored, closeTo(priced, 1),
          reason: 'error sheet $errored dp vs priced sheet $priced dp');
      await _unmount(tester);
    });
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('route preview, error: "Try again" is on screen (text x$scale)',
        (tester) async {
      // No location service on this "device", so loading the route fails.
      await _pump(
        tester,
        const RoutePreviewScreen(destination: _dropoff),
        textScale: scale,
      );
      await tester.pump();

      expect(find.text('Try again'), findsOneWidget);
      expectReachableWithoutScrolling(tester, _button('Try again'));
      await _unmount(tester);
    });
  }

  group('home', () {
    testWidgets('the location error\'s "Try again" is clear of the sheet',
        (tester) async {
      // No location fix, so the map shows its error with a retry button. That
      // used to be centred on the whole screen, with the Where-to sheet drawn
      // over its lower half.
      await _pump(tester, const HomeScreen());
      await tester.pump();

      expect(find.text('Try again'), findsOneWidget);
      expectReachableWithoutScrolling(tester, find.text('Try again'));
      expect(tester.getRect(find.text('Try again')).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(McSheet)).top));
      await _unmount(tester);
    });

    // The whole error block — icon (when there is room for it), message and
    // button — must sit between the Menu / Account circles and the sheet.
    Future<void> expectErrorBlockClear(WidgetTester tester,
        {required bool mayScroll}) async {
      final circles = find.byType(McCircleButton);
      expect(circles, findsNWidgets(2));
      final circleRects = [
        for (var i = 0; i < 2; i++) tester.getRect(circles.at(i)),
      ];
      final floor =
          circleRects.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
      final sheetTop = tester.getRect(find.byType(McSheet)).top;
      final button = find.widgetWithText(FilledButton, 'Try again');

      // Where the block starts out: under no control, and (unless it is allowed
      // to scroll) fully above the sheet.
      final parts = <String, Rect>{
        'message': tester.getRect(find.textContaining('Location is turned off')),
        'button': tester.getRect(button),
        if (find.byIcon(Icons.location_off).evaluate().isNotEmpty)
          'icon': tester.getRect(find.byIcon(Icons.location_off)),
      };
      parts.forEach((name, rect) {
        for (final c in circleRects) {
          expect(rect.overlaps(c), isFalse,
              reason: '$name $rect runs under a control $c');
        }
        if (name != 'button' || !mayScroll) {
          expect(rect.top, greaterThanOrEqualTo(floor),
              reason: '$name $rect starts above the controls (end y=$floor)');
        }
        if (!mayScroll) {
          expect(rect.bottom, lessThanOrEqualTo(sheetTop),
              reason: '$name $rect runs under the sheet (starts y=$sheetTop)');
        }
      });

      if (mayScroll) {
        // What doesn't fit scrolls, and the button is reachable from there.
        await tester.ensureVisible(button);
        await tester.pump();
      }
      expectReachableWithoutScrolling(tester, button);
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(sheetTop),
          reason: 'the button is under the sheet (starts y=$sheetTop)');
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'the location error fits above the sheet on 360x640, no scrolling (text x$scale)',
          (tester) async {
        await _pump(tester, const HomeScreen(), textScale: scale);
        await tester.pump();

        await expectErrorBlockClear(tester, mayScroll: false);
        await _unmount(tester);
      });
    }

    testWidgets(
        'the location error stays below the Menu / Account buttons on a short phone',
        (tester) async {
      // 360x560 at larger text: the error block is taller than the strip of
      // map above the sheet, so what doesn't fit scrolls. It used to be centred
      // on the whole screen, so its icon sat at the very top and the message
      // ran under the circles.
      await _pump(tester, const HomeScreen(),
          textScale: 1.3, size: const Size(360, 560));
      await tester.pump();

      await expectErrorBlockClear(tester, mayScroll: true);
      await _unmount(tester);
    });

    testWidgets('the last saved-place row clears the nav bar', (tester) async {
      await _pump(tester, const HomeScreen());

      expectReachableWithoutScrolling(tester, find.text('Set work address'));
      await _unmount(tester);
    });
  });
}
