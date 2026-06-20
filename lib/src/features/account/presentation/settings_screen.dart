import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <(String, String, VoidCallback?)>[
      ('user', 'Personal info', null),
      ('card', 'Payment', () => context.push('/payment')),
      ('heart', 'Saved places', null),
      ('shield', 'Safety & privacy', null),
      ('bell', 'Notifications', null),
      ('gift', 'Promotions', null),
      ('msg', 'Help', null),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _CustomerTabBar(active: 'account'),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const McTitle('Account', size: 26),
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 8),
                      child: Row(
                        children: [
                          const McAvatar(size: 62, color: Brand.blue),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alex Morgan', style: tw(FontWeight.w900, 18)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Ico('starF', size: 14, color: Brand.star),
                                    const SizedBox(width: 5),
                                    Text('4.92 · alex@email.com',
                                        style: tw(FontWeight.w700, 13, Brand.sub)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Ico('edit', size: 20, color: Brand.sub),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: McCard(
                  padding: 0,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: rows[i].$3,
                          child: Container(
                            decoration: BoxDecoration(
                              border: i < rows.length - 1
                                  ? const Border(bottom: BorderSide(color: Brand.fill))
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Ico(rows[i].$1, size: 21, color: Brand.sub),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(rows[i].$2, style: tw(FontWeight.w700, 15)),
                                ),
                                const Ico('chevR', size: 18, color: Brand.faint),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                    if (context.mounted) context.go('/intro');
                  },
                  child: Text('Log out', style: tw(FontWeight.w800, 14, Brand.blue)),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text('MAP CARS · v1.0.0', style: tw(FontWeight.w600, 12, Brand.faint))),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerTabBar extends StatelessWidget {
  const _CustomerTabBar({required this.active});
  final String active;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('home', 'Home', () => context.go('/home')),
      ('receipt', 'Activity', () => context.go('/activity')),
      ('user', 'Account', () => context.go('/account')),
    ];
    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Brand.paper,
        border: Border(top: BorderSide(color: Brand.fill)),
      ),
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          for (final (icon, label, onTap) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Ico(icon, size: 24, color: active == label.toLowerCase() ? Brand.blue : Brand.faint),
                    const SizedBox(height: 3),
                    Text(label,
                        style: tw(FontWeight.w800, 11,
                            active == label.toLowerCase() ? Brand.blue : Brand.faint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
