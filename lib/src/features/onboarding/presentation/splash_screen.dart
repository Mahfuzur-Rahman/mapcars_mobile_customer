import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// Restore any persisted session, then route the rider to the right place.
  Future<void> _boot() async {
    await ref.read(authNotifierProvider.notifier).restore();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final loggedIn = ref.read(authNotifierProvider).isAuthenticated;
    context.go(loggedIn ? '/home' : '/intro');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/intro'),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: GradientRotation(158 * 3.1415926535 / 180),
              colors: [
                Color(0xFF9CD3EE),
                Color(0xFFD8EDF8),
                Color(0xFFF7FAFC),
                Color(0xFFDCEFD3),
                Color(0xFFACDC99),
              ],
              stops: [0.0, 0.26, 0.50, 0.74, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // soft brand glow blobs
              Positioned(
                top: -60,
                left: -40,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x590B7DC0), Color(0x000B7DC0)],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                right: -40,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x5231A424), Color(0x0031A424)],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/mapcars_logo1.png', height: 180),
                    const SizedBox(height: 22),
                    Text(
                      'RIDE SHARING MADE EASY',
                      style: tw(FontWeight.w800, 15, Brand.sub, 3),
                    ),
                  ],
                ),
              ),
              const Positioned(
                bottom: 54,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Brand.blue),
                    ),
                  ),
                ),
              ),
              // Dev-only shortcut into the screen index. It jumps straight to
              // signed-in screens, so it must never ship in a real build.
              if (AppConfig.showDevNav)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TextButton(
                      onPressed: () => context.push('/screens'),
                      child: Text(
                        'Browse all screens',
                        style: tw(FontWeight.w700, 13, Brand.sub),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
