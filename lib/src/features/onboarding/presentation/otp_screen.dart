import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _code = '';

  Future<void> _verify() async {
    if (_code.length < 6) return;
    final ok = await ref.read(authNotifierProvider.notifier).verifyPhoneOtp(_code);
    if (!mounted || !ok) return;
    final auth = ref.read(authNotifierProvider);
    context.go(auth.isProfileComplete ? '/home' : '/profile-setup');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final phone = auth.pendingPhone ?? '';

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
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
                length: 6,
                boxHeight: 60,
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
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: tw(FontWeight.w600, 13, Colors.red)),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  const Ico('clock', size: 16, color: Brand.faint),
                  const SizedBox(width: 6),
                  Text('Resend code in 0:24', style: tw(FontWeight.w700, 14, Brand.sub)),
                ],
              ),
              const Spacer(),
              McButton(
                auth.isLoading ? 'Verifying…' : 'Verify',
                icon: auth.isLoading ? null : 'check',
                onTap: auth.isLoading ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
