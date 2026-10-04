// Full-page screens pin their primary action (McActionBar), so it is reachable
// without scrolling on a small phone (360x640) with a 3-button nav bar (48dp),
// at normal and larger text, and with the keyboard up where the screen has
// fields.
//
// Before, sign-in / sign-up / OTP / rate / completed / receipt ended their
// scrolling content with the button: the autofocused keyboard (or larger text)
// pushed it off the screen, and the non-scrolling OTP pages overflowed outright.
// An error from a failed submit used to land at the end of that scroll too —
// below the button the customer had just tapped — so each screen's error is
// asserted on screen after a failed submit, with and without the keyboard.
//
// The screens are the real ones, on the real font; only the network is faked.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/network/api_exception.dart';
import 'package:mapcars_mobile/src/core/storage/prefs.dart';
import 'package:mapcars_mobile/src/core/theme/app_theme.dart';
import 'package:mapcars_mobile/src/core/widgets/mc.dart';
import 'package:mapcars_mobile/src/core/widgets/mc_tab_bar.dart';
import 'package:mapcars_mobile/src/features/account/presentation/change_password_screen.dart';
import 'package:mapcars_mobile/src/features/account/presentation/edit_profile_screen.dart';
import 'package:mapcars_mobile/src/features/account/presentation/history_screen.dart';
import 'package:mapcars_mobile/src/features/account/presentation/receipt_screen.dart';
import 'package:mapcars_mobile/src/features/account/presentation/settings_screen.dart';
import 'package:mapcars_mobile/src/features/auth/models/auth_state.dart';
import 'package:mapcars_mobile/src/features/auth/providers/auth_notifier.dart';
import 'package:mapcars_mobile/src/features/auth/services/customer_auth_service.dart';
import 'package:mapcars_mobile/src/features/onboarding/presentation/email_signup_screen.dart';
import 'package:mapcars_mobile/src/features/onboarding/presentation/email_verify_screen.dart';
import 'package:mapcars_mobile/src/features/onboarding/presentation/otp_screen.dart';
import 'package:mapcars_mobile/src/features/onboarding/presentation/phone_screen.dart';
import 'package:mapcars_mobile/src/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:mapcars_mobile/src/features/ride/models/chat_message.dart';
import 'package:mapcars_mobile/src/features/ride/models/driver_location.dart';
import 'package:mapcars_mobile/src/features/ride/models/place.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/completed_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/rate_screen.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/set_route_screen.dart';
import 'package:mapcars_mobile/src/features/ride/providers/search_history_provider.dart';
import 'package:mapcars_mobile/src/features/ride/services/maps_service.dart';
import 'package:mapcars_mobile/src/features/ride/services/ride_service.dart';
import 'package:mapcars_mobile/src/features/ride/services/search_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/reachability.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

Trip _trip({String status = 'Completed'}) => Trip.fromJson({
      'id': 'trip-12345678',
      'status': status,
      'pickup': const Place(
              label: 'Current location', address: '', lat: 51.53, lng: -0.12)
          .toJson(),
      'dropoff': const Place(
              label: 'Heathrow Terminal 5',
              address: 'Wallis Rd, Longford, Hounslow TW6 2GA',
              lat: 51.47,
              lng: -0.45)
          .toJson(),
      'tier': 'economy',
      'farePence': 3450,
      'tipAmount': 2,
      'createdAtUtc': '2026-10-03T10:00:00Z',
      'driver': {
        'name': 'Christopher Wellington',
        'rating': 4.9,
        'vehicle': 'Silver Toyota Prius · Economy',
        'plate': 'LB12 KXR',
        'phone': '+447700900123',
      },
    });

/// An auth service whose network calls all fail with [message].
class _FailingAuthService extends CustomerAuthService {
  _FailingAuthService(this.message) : super(Dio());
  final String message;

  ApiException get _fail => ApiException(message: message);

  @override
  Future<OtpSentResult> sendPhoneOtp(String phone) => throw _fail;
  @override
  Future<OtpSentResult> signUpWithEmail(
          String email, String password, String fullName) =>
      throw _fail;
  @override
  Future<AuthResult> loginWithEmail(String email, String password) =>
      throw _fail;
}

/// An auth notifier that starts from [initial] (e.g. a code was just sent, or
/// the last attempt already failed) instead of from signed-out.
class _SeededAuth extends AuthNotifier {
  _SeededAuth(super.service, super.ref, AuthState initial) {
    state = initial;
  }
}

class _RateRepo implements RideRepository {
  @override
  Future<void> submitRating(String tripId,
          {required int score, String? comment}) =>
      throw ApiException(message: 'We could not save your rating just now.');
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
  Future<List<Trip>> tripHistory() async => const [];
}

// ── Harness ─────────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1.0,
  AuthState? auth,
  List<Override> overrides = const [],
}) async {
  await loadAppFonts();
  configureSmallPhone(tester, textScale: textScale);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      customerAuthServiceProvider
          .overrideWithValue(_FailingAuthService('Wrong email or password.')),
      if (auth != null)
        authNotifierProvider.overrideWith(
            (ref) => _SeededAuth(ref.watch(customerAuthServiceProvider), ref, auth)),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}

/// The keyboard arriving after the screen is up: a field takes focus (the
/// autofocused ones already have it) and the view reports the insets.
Future<void> _openKeyboard(WidgetTester tester, {Finder? field}) async {
  await tester.showKeyboard(field ?? find.byType(TextField).first);
  setKeyboard(tester, open: true);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(McButton, label);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _noExceptions(WidgetTester tester) =>
    expect(tester.takeException(), isNull);

/// The whole [finder] rect lies above the pinned bar's top edge — not just a
/// label clear of the bar while the box is half under it.
void _expectAboveBar(WidgetTester tester, Finder finder) {
  expect(tester.getRect(finder).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(McActionBar)).top + 0.5));
}

const _signedUpEmail = AuthState(email: 'sam@example.com');
const _sentPhone = AuthState(pendingPhone: '+447700900123');

void main() {
  for (final scale in [1.0, 1.3]) {
    group('text x$scale', () {
      // ── phone_screen ──────────────────────────────────────────────────────
      group('phone screen', () {
        testWidgets('Continue is reachable, keyboard closed', (tester) async {
          await _pump(tester, const PhoneScreen(), textScale: scale);
          expectReachableWithoutScrolling(tester, _button('Continue'));
          _noExceptions(tester);
        });

        testWidgets('Continue is reachable with the keyboard open',
            (tester) async {
          await _pump(tester, const PhoneScreen(), textScale: scale);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Continue'));
          _noExceptions(tester);
        });

        testWidgets('email tab: Sign in is reachable with the keyboard open',
            (tester) async {
          await _pump(tester, const PhoneScreen(initialTab: AuthTab.email),
              textScale: scale);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Sign in'));
          _noExceptions(tester);
        });

        for (final keyboard in [false, true]) {
          testWidgets(
              'a failed submit shows its error beside the button '
              '(keyboard ${keyboard ? 'open' : 'closed'})', (tester) async {
            await _pump(tester, const PhoneScreen(), textScale: scale);
            if (keyboard) await _openKeyboard(tester);
            await _tap(tester, _button('Continue'));
            final error = find.text('Please enter your phone number.');
            expectReachableWithoutScrolling(tester, error);
            expectReachableWithoutScrolling(tester, _button('Continue'));
            _noExceptions(tester);
          });

          testWidgets(
              'email tab: an API error shows beside the button '
              '(keyboard ${keyboard ? 'open' : 'closed'})', (tester) async {
            await _pump(tester, const PhoneScreen(initialTab: AuthTab.email),
                textScale: scale);
            await tester.enterText(
                find.byType(TextField).at(0), 'sam@example.com');
            await tester.enterText(find.byType(TextField).at(1), 'secret');
            if (keyboard) await _openKeyboard(tester);
            await _tap(tester, _button('Sign in'));
            expectReachableWithoutScrolling(
                tester, find.text('Wrong email or password.'));
            expectReachableWithoutScrolling(tester, _button('Sign in'));
            _noExceptions(tester);
          });
        }

        testWidgets('Google and "Sign up" stay in the page', (tester) async {
          await _pump(tester, const PhoneScreen(), textScale: scale);
          expect(find.byType(McGoogleButton), findsOneWidget);
          expect(_button('Sign up'), findsOneWidget);
          // Only the primary action is pinned.
          expect(
              find.descendant(
                  of: find.byType(McActionBar),
                  matching: find.byType(McGoogleButton)),
              findsNothing);
          expect(
              find.descendant(
                  of: find.byType(McActionBar), matching: _button('Sign up')),
              findsNothing);
        });
      });

      // ── email_signup_screen ───────────────────────────────────────────────
      group('sign-up screen', () {
        testWidgets('phone: Continue is reachable with the keyboard open',
            (tester) async {
          await _pump(tester, const EmailSignupScreen(), textScale: scale);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Continue'));
          _noExceptions(tester);
        });

        testWidgets('email: Create account is reachable with the keyboard open',
            (tester) async {
          await _pump(
              tester,
              const EmailSignupScreen(initialMethod: SignupMethod.email),
              textScale: scale);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Create account'));
          _noExceptions(tester);
        });

        for (final keyboard in [false, true]) {
          testWidgets(
              'email: "Please fill in every field." shows beside the button '
              '(keyboard ${keyboard ? 'open' : 'closed'})', (tester) async {
            await _pump(
                tester,
                const EmailSignupScreen(initialMethod: SignupMethod.email),
                textScale: scale);
            if (keyboard) await _openKeyboard(tester);
            await _tap(tester, _button('Create account'));
            expectReachableWithoutScrolling(
                tester, find.text('Please fill in every field.'));
            expectReachableWithoutScrolling(tester, _button('Create account'));
            _noExceptions(tester);
          });
        }

        testWidgets('"Sign in" link stays in the page', (tester) async {
          await _pump(tester, const EmailSignupScreen(), textScale: scale);
          expect(
              find.descendant(
                  of: find.byType(McActionBar), matching: _button('Sign in')),
              findsNothing);
          expect(_button('Sign in'), findsOneWidget);
        });
      });

      // ── otp_screen / email_verify_screen ──────────────────────────────────
      group('code screens', () {
        testWidgets('OTP: Verify is reachable, keyboard closed, no overflow',
            (tester) async {
          await _pump(tester, const OtpScreen(),
              textScale: scale, auth: _sentPhone);
          expectReachableWithoutScrolling(tester, _button('Verify'));
          _noExceptions(tester);
        });

        testWidgets('OTP: Verify is reachable with the keyboard open, no overflow',
            (tester) async {
          await _pump(tester, const OtpScreen(),
              textScale: scale, auth: _sentPhone);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Verify'));
          _noExceptions(tester);
        });

        testWidgets('OTP: its error is on screen with the keyboard open',
            (tester) async {
          await _pump(tester, const OtpScreen(),
              textScale: scale,
              auth: const AuthState(
                  pendingPhone: '+447700900123',
                  error: 'That code is not right. Check it and try again.'));
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(
              tester, find.text('That code is not right. Check it and try again.'));
          expectReachableWithoutScrolling(tester, _button('Verify'));
          _noExceptions(tester);
        });

        testWidgets(
            'email verify: Verify is reachable with the keyboard open, no overflow',
            (tester) async {
          await _pump(tester, const EmailVerifyScreen(),
              textScale: scale, auth: _signedUpEmail);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Verify'));
          _noExceptions(tester);
          // Let the code countdown's timer finish with the screen.
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('email verify: its error is on screen with the keyboard open',
            (tester) async {
          await _pump(tester, const EmailVerifyScreen(),
              textScale: scale,
              auth: const AuthState(
                  email: 'sam@example.com',
                  error: 'That code has expired. Request a new one.'));
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(
              tester, find.text('That code has expired. Request a new one.'));
          expectReachableWithoutScrolling(tester, _button('Verify'));
          _noExceptions(tester);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets(
            'email verify: while the code is live, Verify is the pinned action',
            (tester) async {
          await _pump(tester, const EmailVerifyScreen(),
              textScale: scale, auth: _signedUpEmail);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Verify'));
          expect(_button('Resend code'), findsNothing);
          _noExceptions(tester);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets(
            'email verify: once the code expires, "Resend code" is the pinned '
            'action, reachable with the keyboard open', (tester) async {
          await _pump(tester, const EmailVerifyScreen(),
              textScale: scale, auth: _signedUpEmail);
          await _openKeyboard(tester);
          await tester.pump(const Duration(seconds: 181));
          await tester.pump();
          expect(find.text('Code expired'), findsOneWidget);
          expectReachableWithoutScrolling(tester, _button('Resend code'));
          // The dead "Verify" no longer sits there looking tappable.
          expect(_button('Verify'), findsNothing);
          // The only "Resend code" on screen is the pinned one.
          expect(find.text('Resend code'), findsOneWidget);
          _noExceptions(tester);
          await tester.pumpWidget(const SizedBox());
        });
      });

      // ── completed / rate / receipt ────────────────────────────────────────
      testWidgets('completed: "Rate your trip" is reachable', (tester) async {
        await _pump(tester, CompletedScreen(trip: _trip()), textScale: scale);
        expectReachableWithoutScrolling(tester, _button('Rate your trip'));
        expect(find.text('Receipt'), findsOneWidget);
        expect(find.text('Get help'), findsOneWidget);
        _noExceptions(tester);
      });

      group('rate screen', () {
        testWidgets('Submit is reachable with the keyboard open', (tester) async {
          await _pump(tester, RateScreen(trip: _trip()), textScale: scale);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Submit rating'));
          _noExceptions(tester);
        });

        testWidgets('the comment field stays above the pinned bar',
            (tester) async {
          await _pump(tester, RateScreen(trip: _trip()), textScale: scale);
          await _openKeyboard(tester);
          await tester.pumpAndSettle();
          _expectAboveBar(tester, find.byType(McField));
          expectReachableWithoutScrolling(tester, find.byType(TextField));
        });

        for (final keyboard in [false, true]) {
          testWidgets(
              'a failed submit shows its error beside the button '
              '(keyboard ${keyboard ? 'open' : 'closed'})', (tester) async {
            await _pump(tester, RateScreen(trip: _trip()),
                textScale: scale,
                overrides: [rideRepositoryProvider.overrideWithValue(_RateRepo())]);
            await tester.tap(find
                .byWidgetPredicate((w) => w is Ico && w.name == 'star')
                .first);
            await tester.pump();
            if (keyboard) await _openKeyboard(tester);
            await _tap(tester, _button('Submit rating'));
            expectReachableWithoutScrolling(
                tester, find.text('We could not save your rating just now.'));
            expectReachableWithoutScrolling(tester, _button('Submit rating'));
            _noExceptions(tester);
          });
        }
      });

      testWidgets('receipt: "Download receipt" is reachable', (tester) async {
        await _pump(tester, ReceiptScreen(trip: _trip()), textScale: scale);
        expectReachableWithoutScrolling(
            tester, find.widgetWithText(McGhostButton, 'Download receipt'));
        _noExceptions(tester);
      });

      // ── screens that were already pinned ──────────────────────────────────
      group('already-pinned forms', () {
        testWidgets('change password: error and button on screen, keyboard open',
            (tester) async {
          await _pump(tester, const ChangePasswordScreen(), textScale: scale);
          await _openKeyboard(tester);
          await _tap(tester, _button('Change password'));
          expectReachableWithoutScrolling(
              tester, find.text('Enter your current password.'));
          expectReachableWithoutScrolling(tester, _button('Change password'));
          _noExceptions(tester);
        });

        testWidgets('edit profile: Save changes reachable, keyboard open',
            (tester) async {
          await _pump(tester, const EditProfileScreen(), textScale: scale);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Save changes'));
          _noExceptions(tester);
        });

        testWidgets('profile setup: Create account reachable, keyboard open',
            (tester) async {
          await _pump(tester, const ProfileSetupScreen(), textScale: scale);
          await _openKeyboard(tester);
          expectReachableWithoutScrolling(tester, _button('Create account'));
          _noExceptions(tester);
        });
      });
    });
  }

  // The header lives inside the scroll on these forms. With it outside, the
  // bar grown by an error squeezed the fields into a sliver (24dp on profile
  // setup at 1.3) and at 2.0 the fixed part overflowed outright.
  group('forms after a failed submit, keyboard open', () {
    Future<void> failAndCheck(
      WidgetTester tester,
      double scale, {
      required Widget screen,
      required String button,
      required String error,
      Future<void> Function()? beforeSubmit,
    }) async {
      await _pump(tester, screen, textScale: scale);
      await _openKeyboard(tester);
      if (beforeSubmit != null) await beforeSubmit();
      await _tap(tester, _button(button));
      expect(find.text(error), findsOneWidget);
      _noExceptions(tester); // no RenderFlex overflow at any scale
      expectReachableWithoutScrolling(tester, find.text(error));
      expectReachableWithoutScrolling(tester, _button(button));
      // The scroll area keeps at least one field's height (52dp) of the form.
      final viewport = tester.getRect(find
          .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(SingleChildScrollView))
          .first);
      final barTop = tester.getRect(find.byType(McActionBar)).top;
      expect(viewport.bottom, lessThanOrEqualTo(barTop + 0.5));
      if (scale <= 1.3) {
        expect(viewport.height, greaterThanOrEqualTo(52),
            reason: 'the form is squeezed to ${viewport.height}dp above the bar');
      }
    }

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('change password (long error), text x$scale', (tester) async {
        await failAndCheck(
          tester,
          scale,
          screen: const ChangePasswordScreen(),
          button: 'Change password',
          error:
              'New password needs at least 8 characters, one uppercase letter, and one digit.',
          beforeSubmit: () async {
            await tester.enterText(find.byType(TextField).at(0), 'oldpass1');
            await tester.enterText(find.byType(TextField).at(1), 'abc');
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('edit profile, text x$scale', (tester) async {
        await failAndCheck(
          tester,
          scale,
          screen: const EditProfileScreen(),
          button: 'Save changes',
          error: 'Please enter your full name.',
        );
      });

      testWidgets('profile setup, text x$scale', (tester) async {
        await failAndCheck(
          tester,
          scale,
          screen: const ProfileSetupScreen(),
          button: 'Create account',
          error: 'Please enter your full name.',
        );
      });
    }
  });

  testWidgets('phone screen: both tabs are the same height at text x1.3',
      (tester) async {
    await _pump(tester, const PhoneScreen(), textScale: 1.3);
    double tabHeight(String label) => tester
        .getSize(find
            .ancestor(
                of: find.text(label), matching: find.byType(AnimatedContainer))
            .first)
        .height;
    expect(tabHeight('Phone number'), tabHeight('Email & password'));
  });

  // ── lists: the last row clears the tab bar / system inset ────────────────
  testWidgets('settings: the end of the page scrolls clear of the tab bar',
      (tester) async {
    await _pump(tester, const SettingsScreen(), textScale: 1.3);
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final tabs = tester.getRect(find.byType(McTabBar));
    final logOut = tester.getRect(find.widgetWithText(McDangerButton, 'Log out'));
    final footer = tester.getRect(find.textContaining('MAP CARS · v1.0.0'));
    expect(logOut.bottom, lessThan(tabs.top));
    expect(footer.bottom, lessThanOrEqualTo(tabs.top));
    expectReachableWithoutScrolling(
        tester, find.widgetWithText(McDangerButton, 'Log out'));
    _noExceptions(tester);
  });

  testWidgets('history: the last trip scrolls clear of the tab bar',
      (tester) async {
    final trips = [
      for (var i = 0; i < 12; i++) _trip(),
    ];
    await _pump(tester, const HistoryScreen(),
        textScale: 1.3,
        overrides: [tripHistoryProvider.overrideWith((ref) async => trips)]);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final tabs = tester.getRect(find.byType(McTabBar));
    final last = tester.getRect(find.byType(McCard).last);
    expect(last.bottom, lessThan(tabs.top));
    _noExceptions(tester);
  });

  testWidgets('set route: the last recent clears the system inset',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final places = [
      for (var i = 0; i < 14; i++)
        Place(label: 'Place $i', address: '$i High St', lat: 51.5, lng: -0.1),
    ];
    await _pump(tester, const SetRouteScreen(),
        textScale: 1.0,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          googleMapsServiceProvider.overrideWithValue(GoogleMapsService()),
          searchHistoryProvider.overrideWith((ref) =>
              _Recents(SearchHistoryService(prefs), places)),
        ]);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final lastRow = tester.getRect(find.textContaining('Place 13'));
    expect(lastRow.bottom, lessThanOrEqualTo(visibleBottom(tester)),
        reason: 'the last recent ends under the system bar ($lastRow)');
    _noExceptions(tester);
  });
}

class _Recents extends SearchHistoryNotifier {
  _Recents(SearchHistoryService service, List<Place> places)
      : super(service, null) {
    state = places;
  }
}
