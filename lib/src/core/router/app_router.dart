import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../widgets/screen_stepper.dart';
import '../../features/account/presentation/history_screen.dart';
import '../../features/account/presentation/payment_screen.dart';
import '../../features/account/presentation/receipt_screen.dart';
import '../../features/account/presentation/settings_screen.dart';
import '../../features/dev/presentation/screen_index.dart';
import '../../features/onboarding/presentation/intro_screen.dart';
import '../../features/onboarding/presentation/otp_screen.dart';
import '../../features/onboarding/presentation/phone_screen.dart';
import '../../features/onboarding/presentation/profile_setup_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/ride/presentation/choose_ride_screen.dart';
import '../../features/ride/presentation/confirm_screen.dart';
import '../../features/ride/presentation/completed_screen.dart';
import '../../features/ride/presentation/home_screen.dart';
import '../../features/ride/presentation/in_progress_screen.dart';
import '../../features/ride/presentation/rate_screen.dart';
import '../../features/ride/presentation/searching_screen.dart';
import '../../features/ride/presentation/set_route_screen.dart';
import '../../features/ride/presentation/tracking_screen.dart';

/// Ordered walk-through used by the floating Next/Prev stepper.
const List<StepRoute> kCustomerFlow = [
  StepRoute('/', 'Splash'),
  StepRoute('/intro', 'Intro'),
  StepRoute('/phone', 'Phone number'),
  StepRoute('/otp', 'OTP'),
  StepRoute('/profile-setup', 'Profile setup'),
  StepRoute('/home', 'Home'),
  StepRoute('/set-route', 'Set route'),
  StepRoute('/choose-ride', 'Choose ride'),
  StepRoute('/confirm', 'Confirm'),
  StepRoute('/searching', 'Searching'),
  StepRoute('/tracking', 'Tracking'),
  StepRoute('/in-progress', 'In progress'),
  StepRoute('/completed', 'Completed'),
  StepRoute('/rate', 'Rate + tip'),
  StepRoute('/activity', 'Trip history'),
  StepRoute('/receipt', 'Receipt'),
  StepRoute('/payment', 'Payment'),
  StepRoute('/account', 'Account'),
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
      // Keep the prototype walk-through fully open in local dev; enforce real
      // auth gating only in staging/prod builds.
      if (AppConfig.isDev) return null;

      final loggedIn = ref.read(authTokenProvider) != null;
      final path = state.uri.path;

      if (!loggedIn && !_publicRoutes.contains(path)) return '/intro';
      if (loggedIn && (path == '/phone' || path == '/otp')) return '/home';
      return null;
    },
    routes: [
    ShellRoute(
      builder: (context, state, child) =>
          ScreenStepper(routes: kCustomerFlow, current: state.uri.path, child: child),
      routes: [
        // Onboarding
        _r('/', () => const SplashScreen()),
        _r('/intro', () => const IntroScreen()),
        _r('/phone', () => const PhoneScreen()),
        _r('/otp', () => const OtpScreen()),
        _r('/profile-setup', () => const ProfileSetupScreen()),
        // Ride flow
        _r('/home', () => const HomeScreen()),
        _r('/set-route', () => const SetRouteScreen()),
        _r('/choose-ride', () => const ChooseRideScreen()),
        _r('/confirm', () => const ConfirmScreen()),
        _r('/searching', () => const SearchingScreen()),
        _r('/tracking', () => const TrackingScreen()),
        _r('/in-progress', () => const InProgressScreen()),
        _r('/completed', () => const CompletedScreen()),
        _r('/rate', () => const RateScreen()),
        // Account
        _r('/activity', () => const HistoryScreen()),
        _r('/receipt', () => const ReceiptScreen()),
        _r('/payment', () => const PaymentScreen()),
        _r('/account', () => const SettingsScreen()),
        // Prototype screen index
        _r('/screens', () => const ScreenIndexScreen()),
      ],
    ),
    ],
  );
});
