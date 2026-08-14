import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../../ride/demo_trip.dart';
import '../../ride/providers/ride_flow_notifier.dart';

/// Routes whose real map only renders once a trip is active — seed the demo
/// trip before opening these so the preview matches production instead of
/// falling back to static walkthrough art.
const _routesNeedingDemoTrip = {'/searching', '/in-progress', '/chat'};

/// Prototype helper — jump to any screen. Reached from the splash screen.
class ScreenIndexScreen extends ConsumerWidget {
  const ScreenIndexScreen({super.key});

  static const _groups = <String, List<List<String>>>{
    'Onboarding': [
      ['Splash', '/'],
      ['Intro carousel', '/intro'],
      ['Phone number', '/phone'],
      ['OTP verification', '/otp'],
      ['Profile setup', '/profile-setup'],
    ],
    'Ride flow': [
      ['Home (map)', '/home'],
      ['Set pickup / destination', '/set-route'],
      ['Choose ride + fare', '/choose-ride'],
      ['Confirm booking', '/confirm'],
      ['Searching for driver', '/searching'],
      ['Driver assigned + tracking', '/tracking'],
      ['Trip in progress', '/in-progress'],
      ['Trip completed', '/completed'],
      ['Rate + tip', '/rate'],
    ],
    'Account': [
      ['Trip history', '/activity'],
      ['Trip receipt', '/receipt'],
      ['Payment methods', '/payment'],
      ['Profile & settings', '/account'],
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Brand.bg,
      appBar: AppBar(
        backgroundColor: Brand.paper,
        title: const Text('All screens · Customer'),
        titleTextStyle: tw(FontWeight.w900, 18, Brand.ink),
        iconTheme: const IconThemeData(color: Brand.ink),
        actions: [
          Consumer(
            builder: (context, ref, _) => IconButton(
              icon: const Icon(Icons.menu, color: Brand.ink),
              tooltip: 'Open menu',
              onPressed: () => openMenuDrawer(ref),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          for (final entry in _groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(entry.key.toUpperCase(),
                  style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
            ),
            McCard(
              padding: 0,
              child: Column(
                children: [
                  for (int i = 0; i < entry.value.length; i++)
                    InkWell(
                      onTap: () {
                        final path = entry.value[i][1];
                        if (_routesNeedingDemoTrip.contains(path)) {
                          ref.read(rideFlowProvider.notifier).previewDemoTrip(demoTrip);
                        }
                        context.push(path);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: i < entry.value.length - 1
                              ? const Border(bottom: BorderSide(color: Brand.fill))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.value[i][0], style: tw(FontWeight.w700, 15))),
                            const Ico('chevR', size: 18, color: Brand.faint),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
