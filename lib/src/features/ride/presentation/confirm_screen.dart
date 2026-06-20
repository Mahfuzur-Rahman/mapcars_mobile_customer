import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: true,
              markers: [
                MapMarker(0.28, 0.80, MapPin(dest: false)),
                MapMarker(0.72, 0.26, MapPin(dest: true)),
              ],
            ),
          ),
          Positioned(
            top: 58,
            left: 16,
            child: McCircleButton('back', onTap: () => context.pop()),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 418,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const McTitle('Confirm your ride', size: 19),
                    const SizedBox(height: 12),
                    McCard(
                      padding: 14,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
                                ),
                                Container(
                                  width: 2,
                                  height: 40,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: Brand.line,
                                ),
                                Container(
                                  width: 10,
                                  height: 10,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _RouteEnd(title: '40 Canary Wharf', sub: 'Pickup · 3 min away'),
                                SizedBox(height: 14),
                                _RouteEnd(title: 'Tower Bridge, SE1', sub: 'Dropoff · 4.3 mi'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _LineRow(icon: 'car', text: 'Economy', value: '£8.90', divider: true),
                    const _LineRow(icon: 'card', text: 'Visa •••• 4242', value: 'Change', valueColor: Brand.blue, divider: true),
                    const _LineRow(icon: 'gift', text: 'Promo SAVE10', value: '−£0.89', valueColor: Brand.green, divider: false),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 12, 2, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: tw(FontWeight.w800, 15)),
                          Text('£8.01', style: tw(FontWeight.w900, 22)),
                        ],
                      ),
                    ),
                    McButton(
                      'Confirm MAP CARS',
                      icon: 'check',
                      kind: BtnKind.grad,
                      onTap: () => context.go('/searching'),
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

class _RouteEnd extends StatelessWidget {
  const _RouteEnd({required this.title, required this.sub});
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tw(FontWeight.w800, 14)),
        Text(sub, style: tw(FontWeight.w600, 12, Brand.sub)),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.icon,
    required this.text,
    required this.value,
    this.valueColor = Brand.ink,
    required this.divider,
  });
  final String icon;
  final String text;
  final String value;
  final Color valueColor;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: Brand.fill)) : null,
      ),
      child: Row(
        children: [
          Ico(icon, size: 20, color: Brand.sub),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: tw(FontWeight.w700, 14))),
          Text(value, style: tw(FontWeight.w800, 14, valueColor)),
        ],
      ),
    );
  }
}
