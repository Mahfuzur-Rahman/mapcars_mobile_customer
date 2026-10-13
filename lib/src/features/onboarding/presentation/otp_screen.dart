import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import 'widgets/resend_code_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _code = '';

  /// Bumped to rebuild [OtpInput] empty: after a wrong code, and after a resend.
  int _attempt = 0;

  Future<void> _verify() async {
    if (_code.length < 6) return;
    final ok = await ref.read(authNotifierProvider.notifier).verifyPhoneOtp(_code);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _attempt++;
        _code = '';
      });
      return;
    }
    // On success the router has usually moved on already (the token change
    // re-runs its redirect, which picks /home or /profile-setup). This covers
    // the case where it hasn't.
    final auth = ref.read(authNotifierProvider);
    context.go(auth.isProfileComplete ? '/home' : '/profile-setup');
  }

  Future<void> _resend() async {
    final phone = ref.read(authNotifierProvider).pendingPhone;
    if (phone == null) return;
    await ref.read(authNotifierProvider.notifier).sendPhoneOtp(phone);
    if (!mounted) return;
    setState(() {
      _attempt++;
      _code = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final phone = auth.pendingPhone ?? '';

    return Scaffold(
      backgroundColor: Brand.bg,
      // The primary action ("Verify") is pinned in an McActionBar, which pads
      // itself by the bottom inset (so no SafeArea there) and rides above the
      // keyboard. The page scrolls — with the keyboard up the old Spacer column
      // overflowed — and the error sits with the button.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const McNavHeader(fallback: '/phone', showMenu: false),
                    const SizedBox(height: 22),
                    const McTitle('Enter the code', size: 26),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        text: 'Sent to $phone. ',
                        style: tw(FontWeight.w600, 15, Brand.sub),
                        children: [
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => backOr(context, '/phone'),
                              child: Text('Edit', style: tw(FontWeight.w800, 15, Brand.blue)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    OtpInput(
                      key: ValueKey(_attempt),
                      length: 6,
                      boxHeight: 60,
                      autofocus: true,
                      onCompleted: (code) {
                        setState(() => _code = code);
                        _verify();
                      },
                    ),
                    if (AppConfig.showDevOtp && auth.devOtpCode != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCF3D5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEECB5F)),
                        ),
                        child: Row(
                          children: [
                            const Ico('phone', size: 16, color: Color(0xFFB07310)),
                            const SizedBox(width: 8),
                            Text(
                              'Dev OTP: ${auth.devOtpCode}',
                              style: tw(FontWeight.w700, 14, const Color(0xFFB07310)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ResendCodeButton(
                      availableAt: auth.resendAvailableAt,
                      busy: auth.isLoading,
                      onResend: _resend,
                    ),
                  ],
                ),
              ),
            ),
            McActionBar(
              // Errors sit with the button, so they are on screen after tapping it.
              notice: auth.error == null ? null : McErrorBanner(auth.error!),
              children: [
                McButton(
                  auth.isLoading ? 'Verifying…' : 'Verify',
                  icon: auth.isLoading ? null : 'check',
                  onTap: auth.isLoading ? null : _verify,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
