import 'package:flutter/material.dart';

import '../../../core/widgets/mc.dart';

/// What the rider actually pays with today: cash, handed to the driver at
/// drop-off.
///
/// This screen used to list two saved cards — a "default" Visa •••• 4242 and a
/// Mastercard •••• 8801 — above an add-a-card form whose button did nothing.
/// Neither card existed: there is no saved-card API, and the confirm screen
/// already marks Card as "Soon". A rider could reasonably have believed a card
/// of theirs was on file and would be charged.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McNavHeader(title: 'Payment', fallback: '/account'),
              const SizedBox(height: 16),
              Text('HOW YOU PAY', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
              const SizedBox(height: 10),
              McCard(
                padding: 16,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Brand.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Ico('cash', size: 22, color: Brand.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Cash', style: tw(FontWeight.w900, 15)),
                          Text('Pay your driver at the end of the ride',
                              style: tw(FontWeight.w600, 12.5, Brand.sub)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Brand.green.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('Default',
                          style: tw(FontWeight.w800, 11, Brand.green)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('CARDS', style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
              const SizedBox(height: 10),
              McCard(
                padding: 16,
                child: Row(
                  children: [
                    const Ico('card', size: 22, color: Brand.sub),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No cards saved',
                              style: tw(FontWeight.w900, 14.5)),
                          Text(
                              'Card payment is coming soon — you’ll be able to '
                              'add one here.',
                              style: tw(FontWeight.w600, 12.5, Brand.sub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
