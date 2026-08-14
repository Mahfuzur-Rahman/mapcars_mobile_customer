import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/services/rider_auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final token = ref.watch(authTokenProvider);
    final rows = <(String, String, VoidCallback?)>[
      ('user', 'Personal info', () => context.push('/account/edit')),
      ('lock', 'Change password', () => context.push('/account/change-password')),
      ('card', 'Payment', () => context.push('/payment')),
      ('heart', 'Saved places', () => context.push('/account/saved-places')),
      ('shield', 'Safety & privacy', () => _showSafetyPrivacySheet(context)),
      ('bell', 'Notifications', () => _showNotificationsSheet(context)),
      ('globe', 'Follow us & Socials', () => _showSocialsSheet(context)),
      ('msg', 'Help & Support', () => _showHelpSupportSheet(context)),
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
                    const McNavHeader(title: 'Account', fallback: '/home'),
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 8),
                      child: Row(
                        children: [
                          if (auth.hasProfilePicture && token != null)
                            ClipOval(
                              child: Image.network(
                                ref.read(riderAuthServiceProvider).profilePictureUrl(Env.apiBaseUrl),
                                headers: {'Authorization': 'Bearer $token'},
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    const McAvatar(size: 62, color: Brand.blue),
                              ),
                            )
                          else
                            const McAvatar(size: 62, color: Brand.blue),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auth.fullName ?? 'Add your name', style: tw(FontWeight.w900, 18)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Ico('starF', size: 14, color: Brand.star),
                                    const SizedBox(width: 5),
                                    Text('4.92 · ${auth.email ?? auth.phone ?? ''}',
                                        style: tw(FontWeight.w700, 13, Brand.sub)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/account/edit'),
                            child: const Ico('edit', size: 20, color: Brand.sub),
                          ),
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
              const SizedBox(height: 14),
              // Social channels quick bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: McCard(
                  padding: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONNECT WITH MAP CARS',
                          style: tw(FontWeight.w800, 11, Brand.sub, 0.5)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _SocialPill(
                              label: 'Facebook',
                              icon: 'globe',
                              color: const Color(0xFF1877F2),
                              onTap: () => _openUrl(
                                  context, 'https://www.facebook.com/profile.php?id=61592078572248'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SocialPill(
                              label: 'Instagram',
                              icon: 'star',
                              color: const Color(0xFFE4405F),
                              onTap: () => _openUrl(context, 'https://www.instagram.com/map91868/'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SocialPill(
                              label: 'WhatsApp',
                              icon: 'msg',
                              color: const Color(0xFF25D366),
                              onTap: () => _openUrl(context, 'https://wa.me/447389077004'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: McDangerButton(
                  'Log out',
                  icon: 'logout',
                  onTap: () => _confirmLogout(context, ref),
                ),
              ),
              const SizedBox(height: 14),
              Center(child: Text('MAP CARS · v1.0.0 · Chichester, UK', style: tw(FontWeight.w600, 12, Brand.faint))),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching link: $e')),
      );
    }
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You\'ll need to sign in again to book a ride.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancel', style: tw(FontWeight.w700, 14, Brand.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Log out', style: tw(FontWeight.w800, 14, Brand.blue)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(authNotifierProvider.notifier).signOut();
  if (context.mounted) context.go('/intro');
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Ico(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSocialsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Follow & Connect', size: 20),
          const SizedBox(height: 6),
          Text('Official MAP CARS community channels & social updates',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          _LinkTile(
            title: 'Facebook Official Page',
            subtitle: 'facebook.com/profile.php?id=61592078572248',
            icon: 'globe',
            color: const Color(0xFF1877F2),
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'https://www.facebook.com/profile.php?id=61592078572248');
            },
          ),
          const SizedBox(height: 10),
          _LinkTile(
            title: 'Instagram @map91868',
            subtitle: 'instagram.com/map91868',
            icon: 'star',
            color: const Color(0xFFE4405F),
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'https://www.instagram.com/map91868/');
            },
          ),
          const SizedBox(height: 10),
          _LinkTile(
            title: 'WhatsApp Official Chat',
            subtitle: '+44 7389 077004',
            icon: 'msg',
            color: const Color(0xFF25D366),
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'https://wa.me/447389077004');
            },
          ),
        ],
      ),
    ),
  );
}

void _showHelpSupportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Help & Support', size: 20),
          const SizedBox(height: 6),
          Text('Reach our local Chichester support team 24/7',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          _LinkTile(
            title: 'WhatsApp Live Chat',
            subtitle: '+44 7389 077004 (Fastest response)',
            icon: 'msg',
            color: const Color(0xFF25D366),
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'https://wa.me/447389077004');
            },
          ),
          const SizedBox(height: 10),
          _LinkTile(
            title: 'Call Support Helpline',
            subtitle: '01243 252255 · Chichester Dispatch',
            icon: 'nav',
            color: Brand.blue,
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'tel:01243252255');
            },
          ),
          const SizedBox(height: 10),
          _LinkTile(
            title: 'Email Support',
            subtitle: 'info@mapcars.uk',
            icon: 'doc',
            color: Brand.ink,
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'mailto:info@mapcars.uk');
            },
          ),
        ],
      ),
    ),
  );
}

void _showSafetyPrivacySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Safety & Privacy', size: 20),
          const SizedBox(height: 6),
          Text('100% PHV licensed drivers, live GPS tracking, and UK GDPR privacy protection.',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          _LinkTile(
            title: 'Emergency 999 Services',
            subtitle: 'One-tap emergency call',
            icon: 'shield',
            color: Colors.red,
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'tel:999');
            },
          ),
          const SizedBox(height: 10),
          _LinkTile(
            title: 'Privacy Policy & Terms',
            subtitle: 'mapcars.uk/legal/privacy',
            icon: 'doc',
            color: Brand.blue,
            onTap: () {
              Navigator.pop(ctx);
              _openUrl(context, 'https://mapcars.uk/legal/privacy');
            },
          ),
        ],
      ),
    ),
  );
}

void _showNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Notification Settings', size: 20),
          const SizedBox(height: 6),
          Text('Trip updates, driver arrival chimes, and receipts',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Brand.fill.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Ico('bell', size: 22, color: Brand.blue),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Push notifications are active for live trip arrivals and receipts.',
                      style: tw(FontWeight.w700, 13.5, Brand.ink)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Brand.fill.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Brand.line),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Ico(icon, size: 20, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tw(FontWeight.w800, 14.5, Brand.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: tw(FontWeight.w600, 12, Brand.sub)),
                ],
              ),
            ),
            const Ico('chevR', size: 16, color: Brand.faint),
          ],
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
