import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'mc.dart';

/// The customer app's bottom tab bar — Home · Activity · Account. Goes in a
/// Scaffold's `bottomNavigationBar`.
///
/// [active] is the current tab's label, lower-cased: `'home'`, `'activity'` or
/// `'account'`.
///
/// The bar is 66dp plus the space beneath its labels, `max(18, inset)` with
/// `inset` = `MediaQuery.paddingOf(context).bottom`. Both apps target SDK 36, so
/// Android 15+ draws them edge-to-edge, under the navigation bar (~48dp with
/// 3-button navigation), and iOS draws under the home indicator (~34dp). The
/// fixed 84dp bar this replaced lost its labels and the lower half of every
/// tab's hit area under that bar. With no inset (or one under 18dp) it is the
/// original 84dp with 18dp beneath the labels; the 18dp that always sat there is
/// absorbed by a bigger inset rather than stacked on top of it.
class McTabBar extends StatelessWidget {
  const McTabBar({super.key, required this.active});

  final String active;

  @override
  Widget build(BuildContext context) {
    final below = math.max(18.0, MediaQuery.paddingOf(context).bottom);
    final items = [
      ('home', 'Home', () => context.go('/home')),
      ('receipt', 'Activity', () => context.go('/activity')),
      ('user', 'Account', () => context.go('/account')),
    ];
    return Container(
      height: 66 + below,
      decoration: const BoxDecoration(
        color: Brand.paper,
        border: Border(top: BorderSide(color: Brand.fill)),
      ),
      padding: EdgeInsets.only(bottom: below),
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
                    Ico(icon,
                        size: 24,
                        color: active == label.toLowerCase()
                            ? Brand.blue
                            : Brand.faint),
                    const SizedBox(height: 3),
                    Text(label,
                        style: tw(
                            FontWeight.w800,
                            11,
                            active == label.toLowerCase()
                                ? Brand.blue
                                : Brand.faint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
