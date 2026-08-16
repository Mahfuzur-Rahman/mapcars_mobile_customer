import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/error_reporter.dart';
import '../widgets/screen_stepper.dart';
import '../../features/account/presentation/change_password_screen.dart';
import '../../features/account/presentation/edit_profile_screen.dart';
import '../../features/account/presentation/history_screen.dart';
import '../../features/account/presentation/payment_screen.dart';
import '../../features/account/presentation/receipt_screen.dart';
import '../../features/account/presentation/saved_places_screen.dart';
import '../../features/account/presentation/settings_screen.dart';
import '../../features/dev/presentation/screen_index.dart';
import '../../features/onboarding/presentation/email_login_screen.dart';
import '../../features/onboarding/presentation/email_signup_screen.dart';
import '../../features/onboarding/presentation/email_verify_screen.dart';
import '../../features/onboarding/presentation/intro_screen.dart';
import '../../features/onboarding/presentation/otp_screen.dart';
import '../../features/onboarding/presentation/phone_screen.dart';
import '../../features/onboarding/presentation/profile_setup_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/ride/presentation/chat_screen.dart';
import '../../features/ride/presentation/choose_ride_screen.dart';
import '../../features/ride/presentation/confirm_screen.dart';
import '../../features/ride/presentation/completed_screen.dart';
import '../../features/ride/presentation/home_screen.dart';
import '../../features/ride/models/place.dart';
import '../../features/ride/models/trip.dart';
import '../../features/ride/presentation/in_progress_screen.dart';
import '../../features/ride/presentation/rate_screen.dart';
import '../../features/ride/presentation/route_preview_screen.dart';
import '../../features/ride/presentation/searching_screen.dart';
import '../../features/ride/presentation/set_route_screen.dart';
import '../../features/ride/presentation/tracking_screen.dart';
import '../../features/ride/presentation/widgets/ride_gate.dart';

/// Ordered walk-through used by the floating hamburger menu drawer.
///
/// Entries carrying an `icon` are the real user-facing menu: they are the only
/// ones the drawer shows outside dev builds. Everything else is a prototype
/// step — a rider must not be able to jump into `/searching` from a menu.
const List<StepRoute> kCustomerFlow = [
  StepRoute('/', 'Splash', category: 'Onboarding'),
  StepRoute('/intro', 'Intro', category: 'Onboarding'),
  StepRoute('/phone', 'Phone number', category: 'Onboarding'),
  StepRoute('/otp', 'OTP', category: 'Onboarding'),
  StepRoute('/email-login', 'Email log in', category: 'Onboarding'),
  StepRoute('/email-signup', 'Sign up', category: 'Onboarding'),
  StepRoute('/verify-email', 'Email verify', category: 'Onboarding'),
  StepRoute('/profile-setup', 'Profile setup', category: 'Onboarding'),
  StepRoute('/home', 'Home', category: 'Ride Flow', icon: 'home'),
  StepRoute('/set-route', 'Set route', category: 'Ride Flow'),
  StepRoute('/choose-ride', 'Choose ride', category: 'Ride Flow'),
  StepRoute('/confirm', 'Confirm', category: 'Ride Flow'),
  StepRoute('/searching', 'Searching', category: 'Ride Flow'),
  StepRoute('/tracking', 'Tracking', category: 'Ride Flow'),
  StepRoute('/chat', 'Chat', category: 'Ride Flow'),
  StepRoute('/in-progress', 'In progress', category: 'Ride Flow'),
  StepRoute('/completed', 'Completed', category: 'Ride Flow'),
  StepRoute('/rate', 'Rate + tip', category: 'Ride Flow'),
  StepRoute('/activity', 'Trip history', category: 'Account', icon: 'clock'),
  StepRoute('/receipt', 'Receipt', category: 'Account'),
  StepRoute('/payment', 'Payment', category: 'Account', icon: 'card'),
  StepRoute('/account/saved-places', 'Saved places', category: 'Account', icon: 'heart'),
  StepRoute('/account', 'Account', category: 'Account', icon: 'user'),
  StepRoute('/account/edit', 'Edit profile', category: 'Account'),
  StepRoute('/account/change-password', 'Change password', category: 'Account'),
  StepRoute('/screens', 'All Screens Index', category: 'Dev Tools'),
];

GoRoute _r(String path, Widget Function() b) =>
    GoRoute(path: path, builder: (c, s) => b());

/// Routes reachable without a session: the onboarding/auth funnel and the
/// dev-only screen index. `/profile-setup` stays public because the rider is
/// mid-onboarding (just got a token from OTP) when they land there.
const _publicRoutes = {
  '/',
  '/intro',
  '/phone',
  '/otp',
  '/email-login',
  '/email-signup',
  '/verify-email',
  '/profile-setup',
  '/screens',
};

/// Bridges [authTokenProvider] changes to go_router so guards re-evaluate the
/// moment the rider signs in or the session is torn down (e.g. on a 401).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<String?>(authTokenProvider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription<String?> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authTokenProvider) != null;
      final path = state.uri.path;

      // Remember where we are so a crash report names the screen it happened on.
      ErrorReporter.currentRoute = path;

      // Auth gating applies in every build. It used to be skipped in local dev
      // for the prototype walk-through, which meant /home (and every other
      // signed-in screen) was reachable without a session — including straight
      // from the dev screen index.
      if (!loggedIn && !_publicRoutes.contains(path)) return '/intro';

      // The screen index is a prototype tool that links straight into signed-in
      // screens — it only exists in local dev builds.
      if (path == '/screens' && !AppConfig.isDev) return loggedIn ? '/home' : '/intro';
      const authFunnel = {'/phone', '/otp', '/email-login', '/email-signup', '/verify-email'};
      if (loggedIn && authFunnel.contains(path)) return '/home';
      return null;
    },
    routes: [
    ShellRoute(
      // Always mounted. ScreenStepper itself decides between the dev
      // walk-through and the plain user menu — gating the whole shell on
      // showDevNav left the home screen's hamburger button dead in
      // staging/prod builds.
      builder: (context, state, child) =>
          ScreenStepper(routes: kCustomerFlow, current: state.uri.path, child: child),
      routes: [
        // Onboarding
        _r('/', () => const SplashScreen()),
        _r('/intro', () => const IntroScreen()),
        _r('/phone', () => const PhoneScreen()),
        _r('/otp', () => const OtpScreen()),
        _r('/email-login', () => const EmailLoginScreen()),
        _r('/email-signup', () => const EmailSignupScreen()),
        _r('/verify-email', () => const EmailVerifyScreen()),
        _r('/profile-setup', () => const ProfileSetupScreen()),
        // Ride flow
        _r('/home', () => const HomeScreen()),
        _r('/set-route', () => const SetRouteScreen()),
        GoRoute(
          path: '/route-preview',
          builder: (c, s) {
            final dest = s.extra;
            if (dest is! Place) return const SetRouteScreen();
            return RoutePreviewScreen(destination: dest);
          },
        ),
        // Pre-booking: about a route the rider set, not a trip yet.
        _r('/choose-ride',
            () => const RouteGate(child: ChooseRideScreen())),
        _r('/confirm',
            () => const RouteGate(requireOption: true, child: ConfirmScreen())),
        // Booked: every one of these is about a real trip. `RideGate` resolves
        // the rider's own ride from the API when the screen wasn't reached
        // through the booking flow (menu, deep link, restart), and says plainly
        // when there isn't one.
        _r('/searching', () => RideGate(builder: (t) => SearchingScreen(trip: t))),
        _r('/tracking', () => RideGate(builder: (t) => TrackingScreen(trip: t))),
        _r('/chat', () => RideGate(builder: (t) => ChatScreen(trip: t))),
        _r('/in-progress',
            () => RideGate(builder: (t) => InProgressScreen(trip: t))),
        _r(
          '/completed',
          () => RideGate(
            scope: RideGateScope.lastCompletedTrip,
            builder: (t) => CompletedScreen(trip: t),
          ),
        ),
        _r(
          '/rate',
          () => RideGate(
            scope: RideGateScope.lastCompletedTrip,
            builder: (t) => RateScreen(trip: t),
          ),
        ),
        // Account
        _r('/activity', () => const HistoryScreen()),
        GoRoute(
          path: '/receipt',
          builder: (c, s) => ReceiptScreen(trip: s.extra is Trip ? s.extra as Trip : null),
        ),
        _r('/payment', () => const PaymentScreen()),
        _r('/account', () => const SettingsScreen()),
        _r('/account/edit', () => const EditProfileScreen()),
        _r('/account/change-password', () => const ChangePasswordScreen()),
        _r('/account/saved-places', () => const SavedPlacesScreen()),
        // Prototype screen index
        _r('/screens', () => const ScreenIndexScreen()),
      ],
    ),
    ],
  );
});
