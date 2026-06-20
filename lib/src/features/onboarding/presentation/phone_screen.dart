import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final digits = _ctrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (digits.isEmpty) return;
    final ok = await ref.read(authNotifierProvider.notifier).sendPhoneOtp('+44$digits');
    if (ok && mounted) context.go('/otp');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              McCircleButton('back', onTap: () => context.pop()),
              const SizedBox(height: 22),
              const McTitle("What's your number?", size: 26),
              const SizedBox(height: 10),
              Text(
                "We'll text a code to verify your phone. Standard rates apply.",
                style: tw(FontWeight.w600, 15, Brand.sub),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const McField(value: '🇬🇧 +44', width: 104),
                  const SizedBox(width: 10),
                  Expanded(
                    child: McField(
                      controller: _ctrl,
                      placeholder: '7700 900000',
                      editable: true,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: tw(FontWeight.w600, 13, Colors.red)),
              ],
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'By continuing you agree to our ',
                  style: tw(FontWeight.w600, 12, Brand.sub),
                  children: [
                    TextSpan(text: 'Terms', style: tw(FontWeight.w600, 12, Brand.blue)),
                    TextSpan(text: ' & ', style: tw(FontWeight.w600, 12, Brand.sub)),
                    TextSpan(text: 'Privacy Policy', style: tw(FontWeight.w600, 12, Brand.blue)),
                    TextSpan(text: '.', style: tw(FontWeight.w600, 12, Brand.sub)),
                  ],
                ),
              ),
              const Spacer(),
              McButton(
                auth.isLoading ? 'Sending…' : 'Continue',
                icon: auth.isLoading ? null : 'chevR',
                onTap: auth.isLoading ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
