import 'package:flutter/material.dart';

import '../../../core/router/nav.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';
import '../../ride/models/driver_info.dart';
import '../../ride/models/trip.dart';

/// A real trip receipt. Opened from the Activity list (and the completed
/// screen) with the [Trip] passed as the route's `extra`. Falls back to an
/// empty state if navigated to directly without a trip.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, this.trip});

  final Trip? trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    if (t == null) {
      return Scaffold(
        backgroundColor: Brand.bg,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: McFloatingNav(
                  showHome: false,
                  onBack: () => backOr(context, '/activity'),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Ico('receipt', size: 40, color: Brand.faint),
                    const SizedBox(height: 12),
                    Text('No trip selected', style: tw(FontWeight.w900, 17)),
                    const SizedBox(height: 6),
                    Text('Open a trip from your activity to see its receipt.',
                        textAlign: TextAlign.center,
                        style: tw(FontWeight.w600, 13, Brand.sub)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final subline = [
      if (t.createdAt != null)
        '${formatLongDate(t.createdAt!)} · ${formatClockTime(t.createdAt!)}',
      if (t.distanceMiles != null) '${t.distanceMiles!.toStringAsFixed(1)} mi',
      if (t.durationMinutes != null) '${t.durationMinutes!.round()} min',
    ].join(' · ');

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
                  right: 16,
                  child: McFloatingNav(onBack: () => backOr(context, '/activity')),
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
                  McTitle(
                    t.dropoff.label.isNotEmpty ? t.dropoff.label : 'Trip',
                    size: 22,
                  ),
                  if (subline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subline, style: tw(FontWeight.w600, 13, Brand.sub)),
                  ],
                  const SizedBox(height: 16),
                  McCard(
                    child: Column(
                      children: [
                        if (t.driver != null) ...[
                          _DriverRow(driver: t.driver!),
                          const Divider(height: 1, color: Brand.fill),
                          const SizedBox(height: 8),
                        ],
                        _LineItem('${t.tierLabel.isEmpty ? 'Trip' : t.tierLabel} fare',
                            t.formattedFare ?? '—'),
                        if (t.formattedTip != null) _LineItem('Tip', t.formattedTip!),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Brand.fill),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: tw(FontWeight.w900, 16)),
                            Text(t.formattedTotal ?? '—', style: tw(FontWeight.w900, 20)),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.only(top: 12),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Brand.fill)),
                          ),
                          child: Row(
                            children: [
                              Ico(t.isCash ? 'cash' : 'card', size: 18, color: Brand.sub),
                              const SizedBox(width: 8),
                              Text(t.paymentMethodLabel,
                                  style: tw(FontWeight.w700, 13, Brand.sub)),
                              const Spacer(),
                              Text(
                                t.isPaid ? 'Paid' : 'Due on arrival',
                                style: tw(FontWeight.w800, 12.5,
                                    t.isPaid ? Brand.green : Brand.sub),
                              ),
                            ],
                          ),
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

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.driver});
  final DriverInfo driver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const McAvatar(size: 44, color: Brand.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.name.isNotEmpty ? driver.name : 'Driver',
                    style: tw(FontWeight.w900, 15)),
                if (driver.vehicle.isNotEmpty || driver.plate.isNotEmpty)
                  Text(
                    [driver.vehicle, driver.plate].where((s) => s.isNotEmpty).join(' · '),
                    style: tw(FontWeight.w600, 12.5, Brand.sub),
                  ),
              ],
            ),
          ),
          if (driver.rating > 0) ...[
            const Ico('starF', size: 14, color: Brand.star),
            const SizedBox(width: 3),
            Text(driver.rating.toStringAsFixed(1), style: tw(FontWeight.w800, 13)),
          ],
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tw(FontWeight.w600, 14, Brand.sub)),
          Text(value, style: tw(FontWeight.w700, 14, Brand.ink)),
        ],
      ),
    );
  }
}
