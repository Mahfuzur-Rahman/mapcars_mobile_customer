import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    _nameCtrl = TextEditingController(text: auth.fullName ?? '');
    _emailCtrl = TextEditingController(text: auth.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final email = _emailCtrl.text.trim();
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(name, email.isEmpty ? null : email);
    if (ok && mounted) context.go('/home');
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
              const McTitle('Set up your profile', size: 26),
              const SizedBox(height: 8),
              Text(
                'So drivers know who to pick up.',
                style: tw(FontWeight.w600, 15, Brand.sub),
              ),
              const SizedBox(height: 22),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const McAvatar(size: 92),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Brand.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Center(
                          child: Ico('plus', size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              McField(
                icon: 'user',
                placeholder: 'Your full name',
                controller: _nameCtrl,
                editable: true,
              ),
              const SizedBox(height: 12),
              McField(
                icon: 'msg',
                placeholder: 'Email (optional)',
                controller: _emailCtrl,
                editable: true,
                keyboardType: TextInputType.emailAddress,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: tw(FontWeight.w600, 13, Colors.red)),
              ],
              const Spacer(),
              McButton(
                auth.isLoading ? 'Saving…' : 'Create account',
                icon: auth.isLoading ? null : 'check',
                onTap: auth.isLoading ? null : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
