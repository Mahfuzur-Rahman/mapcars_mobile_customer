import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class InProgressScreen extends StatelessWidget {
  const InProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: true,
              markers: [
                MapMarker(0.44, 0.58, CarMark()),
                MapMarker(0.72, 0.26, MapPin(dest: true)),
              ],
            ),
          ),
          // Floating status pill.
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.go('/completed'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Brand.ink,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x47283443), blurRadius: 18, offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    const Ico('car', size: 22, color: Brand.lime),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('On trip · 12 min left', style: tw(FontWeight.w900, 16, Colors.white)),
                        Text('3.1 mi · arriving 4:38 PM',
                            style: tw(FontWeight.w600, 12, Colors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 296,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Destination row.
                    Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: Brand.blue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tower Bridge, SE1', style: tw(FontWeight.w900, 15)),
                              Text('Destination', style: tw(FontWeight.w600, 12, Brand.sub)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Progress bar ~62%.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: SizedBox(
                            width: 90,
                            height: 6,
                            child: Stack(
                              children: [
                                Container(color: Brand.fill),
                                FractionallySizedBox(
                                  widthFactor: 0.62,
                                  child: Container(
                                    decoration: const BoxDecoration(gradient: Brand.grad),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _DriverRow(),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: McGhostButton('Safety', icon: 'shield'),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: McGhostButton('Share trip', icon: 'nav'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow();

  @override
  Widget build(BuildContext context) {
    return McCard(
      padding: 14,
      child: Row(
        children: [
          const McAvatar(size: 52, color: Brand.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('James K.', style: tw(FontWeight.w900, 16)),
                    const SizedBox(width: 6),
                    const Ico('starF', size: 14, color: Brand.star),
                    const SizedBox(width: 3),
                    Text('4.9', style: tw(FontWeight.w800, 13)),
                  ],
                ),
                Text('Silver Toyota Prius · Economy', style: tw(FontWeight.w600, 12.5, Brand.sub)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Brand.fill, borderRadius: BorderRadius.circular(7)),
            child: Text('LB12 KXR', style: tw(FontWeight.w900, 14, Brand.ink, 0.5)),
          ),
        ],
      ),
    );
  }
}
