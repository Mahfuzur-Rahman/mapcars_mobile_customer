import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: true,
              markers: [
                MapMarker(0.28, 0.78, MapPin(dest: false)),
                MapMarker(0.56, 0.50, CarMark()),
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
              onTap: () => context.go('/in-progress'),
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
                        Text('Arriving in 3 min', style: tw(FontWeight.w900, 16, Colors.white)),
                        Text('James is on the way',
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
              height: 332,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DriverRow(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Meet at 40 Canary Wharf', style: tw(FontWeight.w700, 13)),
                          ),
                          Text('PIN 4821', style: tw(FontWeight.w800, 12, Brand.blue)),
                        ],
                      ),
                    ),
                    McGhostButton('Cancel ride', icon: 'x', onTap: () => context.go('/home')),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: _MiniButton(icon: 'phone', label: 'Call')),
              SizedBox(width: 10),
              Expanded(child: _MiniButton(icon: 'msg', label: 'Message')),
              SizedBox(width: 10),
              Expanded(child: _MiniButton(icon: 'shield', label: 'Safety')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(color: Brand.fill, borderRadius: BorderRadius.circular(13)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Ico(icon, size: 18, color: Brand.ink),
          const SizedBox(height: 1),
          Text(label, style: tw(FontWeight.w800, 10.5, Brand.sub)),
        ],
      ),
    );
  }
}
