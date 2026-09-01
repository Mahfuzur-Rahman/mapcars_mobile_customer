import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mc.dart';

/// Support and safety sheets, plus the two primitives they are built from.
///
/// These began as private helpers inside `settings_screen.dart`. They moved here
/// when the ride screens needed them too: "Get help" on the completed screen and
/// the in-ride safety sheet both want the same tiles and the same launcher, and
/// a rider should not get a different-looking help sheet depending on which
/// screen they opened it from.

/// Opens [url] in the appropriate external app, surfacing any failure as a
/// snackbar rather than silently doing nothing — a dead-looking tap is exactly
/// the problem these sheets exist to fix.
Future<void> openExternalUrl(BuildContext context, String url) async {
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

/// One tappable row in a support sheet: icon chip, title, subtitle, chevron.
class LinkTile extends StatelessWidget {
  const LinkTile({
    super.key,
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
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: GestureDetector(
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
      ),
    );
  }
}

/// Shared chrome for every sheet in this file.
Future<void> showSupportSheet(
  BuildContext context, {
  required String title,
  required String blurb,
  required List<Widget> Function(BuildContext sheetContext) tiles,
}) {
  return showModalBottomSheet<void>(
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
          McTitle(title, size: 20),
          const SizedBox(height: 6),
          Text(blurb, style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          ...tiles(ctx),
        ],
      ),
    ),
  );
}

/// How to reach a human. Opened from Settings and from the completed-ride
/// screen's "Get help".
Future<void> showHelpSupportSheet(BuildContext context) {
  return showSupportSheet(
    context,
    title: 'Help & Support',
    blurb: 'Reach our local Chichester support team 24/7',
    tiles: (ctx) => [
      LinkTile(
        title: 'WhatsApp Live Chat',
        subtitle: '+44 7389 077004 (Fastest response)',
        icon: 'msg',
        color: const Color(0xFF25D366),
        onTap: () {
          Navigator.pop(ctx);
          openExternalUrl(context, 'https://wa.me/447389077004');
        },
      ),
      const SizedBox(height: 10),
      LinkTile(
        title: 'Call Support Helpline',
        subtitle: '01243 252255 · Chichester Dispatch',
        icon: 'nav',
        color: Brand.blue,
        onTap: () {
          Navigator.pop(ctx);
          openExternalUrl(context, 'tel:01243252255');
        },
      ),
      const SizedBox(height: 10),
      LinkTile(
        title: 'Email Support',
        subtitle: 'info@mapcars.uk',
        icon: 'doc',
        color: Brand.ink,
        onTap: () {
          Navigator.pop(ctx);
          openExternalUrl(context, 'mailto:info@mapcars.uk');
        },
      ),
    ],
  );
}

/// The Settings entry — policy and the 999 shortcut. The *in-ride* safety sheet
/// is a different, trip-aware thing; see `ride/presentation/widgets/trip_safety.dart`.
Future<void> showSafetyPrivacySheet(BuildContext context) {
  return showSupportSheet(
    context,
    title: 'Safety & Privacy',
    blurb:
        '100% PHV licensed drivers, live GPS tracking, and UK GDPR privacy protection.',
    tiles: (ctx) => [
      LinkTile(
        title: 'Emergency 999 Services',
        subtitle: 'One-tap emergency call',
        icon: 'shield',
        color: Colors.red,
        onTap: () {
          Navigator.pop(ctx);
          openExternalUrl(context, 'tel:999');
        },
      ),
      const SizedBox(height: 10),
      LinkTile(
        title: 'Privacy Policy & Terms',
        subtitle: 'mapcars.uk/legal/privacy',
        icon: 'doc',
        color: Brand.blue,
        onTap: () {
          Navigator.pop(ctx);
          openExternalUrl(context, 'https://mapcars.uk/legal/privacy');
        },
      ),
    ],
  );
}
