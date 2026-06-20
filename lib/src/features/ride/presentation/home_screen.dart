import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: false,
              markers: [
                MapMarker(0.46, 0.40, MapPin(dest: false)),
              ],
            ),
          ),
          Positioned(
            top: 58,
            left: 16,
            child: McCircleButton('menu', onTap: () => context.go('/activity')),
          ),
          Positioned(
            top: 58,
            right: 16,
            child: McCircleButton('user', onTap: () => context.go('/account')),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 392,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const McTitle('Where to?', size: 22),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Ico('clock', size: 16, color: Brand.sub),
                          const SizedBox(width: 5),
                          Text('Now', style: tw(FontWeight.w700, 13, Brand.sub)),
                          const SizedBox(width: 2),
                          const Ico('chevD', size: 14, color: Brand.sub),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  McField(
                    icon: 'search',
                    placeholder: 'Enter destination',
                    onTap: () => context.go('/set-route'),
                  ),
                  const SizedBox(height: 14),
                  _SavedRow(
                    icon: 'home',
                    title: 'Home',
                    sub: '12 Oak Street, SE1',
                    divider: true,
                    onTap: () => context.go('/set-route'),
                  ),
                  _SavedRow(
                    icon: 'heart',
                    title: 'Work',
                    sub: '40 Canary Wharf, E14',
                    divider: true,
                    onTap: () => context.go('/set-route'),
                  ),
                  _SavedRow(
                    icon: 'clock',
                    title: 'Aldgate Station',
                    sub: 'Recent · 2.1 mi',
                    divider: false,
                    onTap: () => context.go('/set-route'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.divider,
    this.onTap,
  });
  final String icon;
  final String title;
  final String sub;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: Brand.fill))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: Brand.fill, shape: BoxShape.circle),
              child: Center(child: Ico(icon, size: 19, color: Brand.sub)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tw(FontWeight.w800, 15)),
                  Text(sub, style: tw(FontWeight.w600, 12.5, Brand.sub)),
                ],
              ),
            ),
            const Ico('chevR', size: 18, color: Brand.faint),
          ],
        ),
      ),
    );
  }
}
