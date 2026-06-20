import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class SetRouteScreen extends StatelessWidget {
  const SetRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.paper,
      body: Column(
        children: [
          Container(
            color: Brand.paper,
            padding: const EdgeInsets.fromLTRB(18, 60, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      child: const Ico('back', size: 24, color: Brand.ink),
                    ),
                    const SizedBox(width: 12),
                    const McTitle('Plan your trip', size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                // connected pickup -> dest
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
                          ),
                          Container(
                            width: 2,
                            height: 70,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Brand.line,
                          ),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Brand.blue,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        children: [
                          McField(value: 'Current location'),
                          SizedBox(height: 8),
                          McField(placeholder: 'Where to?', editable: true, autofocus: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.go('/choose-ride'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Brand.blue.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(child: Ico('pin', size: 18, color: Brand.blue)),
                        ),
                        const SizedBox(width: 10),
                        Text('Set location on map', style: tw(FontWeight.w800, 15, Brand.blue)),
                      ],
                    ),
                  ),
                ),
                _SuggestionRow(
                  title: 'Tower Bridge',
                  sub: 'London SE1 2UP',
                  dist: '1.4 mi',
                  onTap: () => context.go('/choose-ride'),
                ),
                _SuggestionRow(
                  title: 'Borough Market',
                  sub: '8 Southwark St, SE1',
                  dist: '0.9 mi',
                  onTap: () => context.go('/choose-ride'),
                ),
                _SuggestionRow(
                  title: 'Liverpool St Station',
                  sub: 'London EC2M 7PY',
                  dist: '2.7 mi',
                  onTap: () => context.go('/choose-ride'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.title,
    required this.sub,
    required this.dist,
    this.onTap,
  });
  final String title;
  final String sub;
  final String dist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Brand.fill)),
        ),
        child: Row(
          children: [
            const Ico('pin', size: 20, color: Brand.sub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tw(FontWeight.w800, 14.5)),
                  Text(sub, style: tw(FontWeight.w600, 12.5, Brand.sub)),
                ],
              ),
            ),
            Text(dist, style: tw(FontWeight.w700, 12, Brand.faint)),
          ],
        ),
      ),
    );
  }
}
