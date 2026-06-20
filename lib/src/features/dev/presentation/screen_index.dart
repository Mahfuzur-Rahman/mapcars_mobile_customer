import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

/// Prototype helper — jump to any screen. Reached from the splash screen.
class ScreenIndexScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      appBar: AppBar(
        backgroundColor: Brand.paper,
        title: const Text('All screens · Customer'),
        titleTextStyle: tw(FontWeight.w900, 18, Brand.ink),
        iconTheme: const IconThemeData(color: Brand.ink),
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
                      onTap: () => context.push(entry.value[i][1]),
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
