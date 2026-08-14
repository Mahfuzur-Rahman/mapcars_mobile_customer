import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

enum AuthTab { phone, email }

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, this.initialTab = AuthTab.phone});

  final AuthTab initialTab;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  late AuthTab _tab;
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _continuePhone() async {
    final digits = _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (digits.isEmpty) {
      setState(() => _localError = 'Please enter your phone number.');
      return;
    }
    setState(() => _localError = null);
    final ok = await ref.read(authNotifierProvider.notifier).sendPhoneOtp('+44$digits');
    if (ok && mounted) context.go('/otp');
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _localError = null);
    final ok =
        await ref.read(authNotifierProvider.notifier).continueWithGoogle(signUp: true);
    if (!ok || !mounted) return;
    final complete = ref.read(authNotifierProvider).isProfileComplete;
    context.go(complete ? '/home' : '/profile-setup');
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _localError = 'Please enter both email and password.');
      return;
    }
    setState(() => _localError = null);

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .loginWithEmail(email, password);

    if (ok && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final error = _localError ?? auth.error;
    final isPhone = _tab == AuthTab.phone;

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McNavHeader(fallback: '/intro', showMenu: false),
              const SizedBox(height: 18),

              // Segmented tab switch for Phone / Email
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Brand.line.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Phone number',
                        icon: 'phone',
                        active: isPhone,
                        onTap: () {
                          setState(() {
                            _tab = AuthTab.phone;
                            _localError = null;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Email & password',
                        icon: 'mail',
                        active: !isPhone,
                        onTap: () {
                          setState(() {
                            _tab = AuthTab.email;
                            _localError = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              McTitle(
                isPhone ? "What's your number?" : "Log in with email",
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                isPhone
                    ? "We'll text a code to verify your phone. Standard rates apply."
                    : "Enter your registered email and password to sign in.",
                style: tw(FontWeight.w600, 15, Brand.sub),
              ),
              const SizedBox(height: 22),

              if (isPhone) ...[
                Row(
                  children: [
                    const McField(value: '🇬🇧 +44', width: 104),
                    const SizedBox(width: 10),
                    Expanded(
                      child: McField(
                        controller: _phoneCtrl,
                        placeholder: '7700 900000',
                        editable: true,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                McField(
                  icon: 'mail',
                  placeholder: 'Email address',
                  controller: _emailCtrl,
                  editable: true,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                McField(
                  icon: 'lock',
                  placeholder: 'Password',
                  controller: _passwordCtrl,
                  editable: true,
                  obscure: _obscurePassword,
                  suffix: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Brand.sub,
                    ),
                  ),
                ),
              ],

              if (error != null) ...[
                const SizedBox(height: 14),
                McErrorBanner(error),
              ],

              const SizedBox(height: 24),
              McButton(
                auth.isLoading
                    ? (isPhone ? 'Sending…' : 'Signing in…')
                    : (isPhone ? 'Continue' : 'Sign in'),
                icon: auth.isLoading ? null : 'chevR',
                onTap: auth.isLoading
                    ? null
                    : (isPhone ? _continuePhone : _submitEmail),
              ),

              const SizedBox(height: 18),
              const McDividerLabel('or'),
              const SizedBox(height: 14),
              McGoogleButton(
                loading: auth.isLoading,
                onTap: auth.isLoading ? null : _continueWithGoogle,
              ),

              const SizedBox(height: 20),
              const McDividerLabel("Don't have an account?"),
              const SizedBox(height: 14),
              McButton(
                'Sign up',
                icon: 'user',
                kind: BtnKind.green,
                onTap: () => context.go('/email-signup'),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'By continuing you agree to our ',
                  style: tw(FontWeight.w600, 12, Brand.sub),
                  children: [
                    TextSpan(
                        text: 'Terms',
                        style: tw(FontWeight.w600, 12, Brand.blue)),
                    TextSpan(
                        text: ' & ', style: tw(FontWeight.w600, 12, Brand.sub)),
                    TextSpan(
                        text: 'Privacy Policy',
                        style: tw(FontWeight.w600, 12, Brand.blue)),
                    TextSpan(
                        text: '.', style: tw(FontWeight.w600, 12, Brand.sub)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Brand.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Ico(icon, size: 16, color: active ? Brand.blue : Brand.sub),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: tw(
                  FontWeight.w800,
                  13.5,
                  active ? Brand.ink : Brand.sub,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
