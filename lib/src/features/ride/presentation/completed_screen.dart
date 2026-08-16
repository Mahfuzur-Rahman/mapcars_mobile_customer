import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../models/trip.dart';

class CompletedScreen extends ConsumerWidget {
  const CompletedScreen({super.key, required this.trip});

  /// The finished ride — always a real one, supplied by `RideGate`.
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverName = trip.driver?.name;
    final fare = trip.formattedFare;
    final tip = trip.formattedTip;
    final total = trip.formattedTotal;

    // Real payment state (cash today; card once Stripe lands).
    final payIcon = trip.isCash ? 'cash' : 'card';
    final payLabel = trip.paymentMethodLabel;
    final payNote = trip.isPaid ? 'Paid' : 'Due on arrival';

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // End of the trip — nothing to go back to, but Home and the menu
              // stay reachable.
              const McNavHeader(showBack: false),
              const SizedBox(height: 18),
              // Success header.
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: Brand.gradGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x5F31A424), blurRadius: 20, offset: Offset(0, 8)),
                      ],
                    ),
                    child: const Center(child: Ico('check', size: 34, color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  const McTitle("You've arrived", size: 23, align: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                      driverName == null
                          ? 'Hope you enjoyed your ride'
                          : 'Hope you enjoyed the ride with $driverName',
                      textAlign: TextAlign.center,
                      style: tw(FontWeight.w600, 13.5, Brand.sub)),
                ],
              ),
              const SizedBox(height: 18),
              // Fare summary card.
              McCard(
                padding: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Only what the trip actually carries. The old fallback
                    // invented an "Economy fare £8.90 / Promo SAVE10 −£0.89 /
                    // Booking fee" breakdown and an £8.01 total.
                    _FareRow(
                        '${trip.tierLabel.isEmpty ? 'Trip' : trip.tierLabel} fare',
                        fare ?? '—'),
                    if (tip != null) _FareRow('Tip', tip),
                    Container(height: 1, color: Brand.fill, margin: const EdgeInsets.symmetric(vertical: 8)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total paid', style: tw(FontWeight.w900, 16)),
                        Text(total ?? '—', style: tw(FontWeight.w900, 20)),
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
                          Ico(payIcon, size: 18, color: Brand.sub),
                          const SizedBox(width: 8),
                          Text(payLabel, style: tw(FontWeight.w700, 13, Brand.sub)),
                          const Spacer(),
                          Text(payNote,
                              style: tw(FontWeight.w800, 12,
                                  trip.isPaid ? Brand.green : Brand.sub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: McGhostButton(
                      'Receipt',
                      icon: 'receipt',
                      height: 48,
                      onTap: () => context.push('/receipt', extra: trip),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: McGhostButton('Get help', icon: 'msg', height: 48)),
                ],
              ),
              const SizedBox(height: 18),
              McButton('Rate your trip', icon: 'star', onTap: () => context.go('/rate')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow(this.label, this.amount);
  final String label;
  final String amount;
  static const value = Brand.ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tw(FontWeight.w600, 14, Brand.sub)),
          Text(amount, style: tw(FontWeight.w700, 14, value)),
        ],
      ),
    );
  }
}
