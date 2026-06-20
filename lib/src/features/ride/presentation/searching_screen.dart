import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) context.go('/tracking');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapBackground(
              route: false,
              markers: [
                MapMarker(
                  0.46,
                  0.40,
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _pulse(150, 0.08),
                        _pulse(100, 0.13),
                        _pulse(60, 0.20),
                        const MapPin(dest: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Brand.blue),
                          backgroundColor: Brand.fill,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const McTitle('Finding your driver…', size: 19),
                            Text(
                              'Matching you with a nearby MAP CARS',
                              style: tw(FontWeight.w600, 13, Brand.sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  McCard(
                    padding: 14,
                    child: Row(
                      children: [
                        const Ico('car', size: 22, color: Brand.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Economy', style: tw(FontWeight.w800, 14)),
                              Text('£8.01 · Visa •••• 4242', style: tw(FontWeight.w600, 12, Brand.sub)),
                            ],
                          ),
                        ),
                        Text('Tower Bridge', style: tw(FontWeight.w700, 12, Brand.sub)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  McGhostButton('Cancel request', onTap: () => context.go('/home')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulse(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Brand.blue.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );
}
