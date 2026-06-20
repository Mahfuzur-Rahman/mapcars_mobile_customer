import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  static const _lineItems = [
    ('Economy fare', '£8.90'),
    ('Promo SAVE10', '−£0.89'),
    ('Tip', '£2.00'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: MapBackground(
                    route: true,
                    markers: [
                      MapMarker(0.30, 0.74, MapPin(dest: false)),
                      MapMarker(0.70, 0.34, MapPin(dest: true)),
                    ],
                  ),
                ),
                Positioned(
                  top: 56,
                  left: 16,
                  child: McCircleButton('back', onTap: () => context.pop()),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const McTitle('Tower Bridge, SE1', size: 22),
                  const SizedBox(height: 4),
                  Text('14 June 2026 · 4:38 PM · 4.3 mi · 18 min',
                      style: tw(FontWeight.w600, 13, Brand.sub)),
                  const SizedBox(height: 16),
                  McCard(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              const McAvatar(size: 44, color: Brand.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('James K.', style: tw(FontWeight.w900, 15)),
                                    Text('Silver Toyota Prius · LB12 KXR',
                                        style: tw(FontWeight.w600, 12.5, Brand.sub)),
                                  ],
                                ),
                              ),
                              const Ico('starF', size: 14, color: Brand.star),
                              const SizedBox(width: 3),
                              Text('4.9', style: tw(FontWeight.w800, 13)),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Brand.fill),
                        const SizedBox(height: 8),
                        for (final (label, value) in _lineItems)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(label, style: tw(FontWeight.w600, 14, Brand.sub)),
                                Text(value,
                                    style: tw(FontWeight.w700, 14,
                                        value.startsWith('−') ? Brand.green : Brand.ink)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Brand.fill),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: tw(FontWeight.w900, 16)),
                            Text('£10.01', style: tw(FontWeight.w900, 20)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const McGhostButton('Download receipt', icon: 'receipt'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
