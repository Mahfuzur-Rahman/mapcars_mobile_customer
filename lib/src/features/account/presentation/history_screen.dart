import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _trips = [
    ('Tower Bridge, SE1', 'Today · 4:38 PM', '£8.01', 'Economy', true),
    ('Heathrow Terminal 5', 'Yesterday · 9:12 AM', '£42.60', 'XL', true),
    ('Borough Market', 'Mon · 1:05 PM', '£6.20', 'Economy', true),
    ('Shoreditch High St', 'Sun · 11:48 PM', '£14.90', 'Comfort', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _CustomerTabBar(active: 'activity'),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: McTitle('Your trips', size: 26),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final (dest, whenText, fare, type, rated) = _trips[i];
                  return GestureDetector(
                    onTap: () => context.push('/receipt'),
                    child: McCard(
                      padding: 14,
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Brand.fill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(child: Ico('car', size: 24, color: Brand.sub)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(dest,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tw(FontWeight.w900, 15)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(fare, style: tw(FontWeight.w900, 15)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('$whenText · $type',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tw(FontWeight.w600, 12.5, Brand.sub)),
                                    ),
                                    const SizedBox(width: 8),
                                    if (rated)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Ico('starF', size: 13, color: Brand.star),
                                          const SizedBox(width: 3),
                                          Text('Rated', style: tw(FontWeight.w800, 12, Brand.sub)),
                                        ],
                                      )
                                    else
                                      Text('Rate now', style: tw(FontWeight.w800, 12, Brand.blue)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
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
