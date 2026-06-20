import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class CompletedScreen extends StatelessWidget {
  const CompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        BoxShadow(color: Color(0x594FBF3B), blurRadius: 20, offset: Offset(0, 8)),
                      ],
                    ),
                    child: const Center(child: Ico('check', size: 34, color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  const McTitle("You've arrived", size: 23, align: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Hope you enjoyed the ride with James',
                      textAlign: TextAlign.center, style: tw(FontWeight.w600, 13.5, Brand.sub)),
                ],
              ),
              const SizedBox(height: 18),
              // Fare summary card.
              McCard(
                padding: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FareRow('Economy fare', '£8.90'),
                    const _FareRow('Promo SAVE10', '−£0.89', value: Brand.green),
                    const _FareRow('Booking fee', '£0.00'),
                    Container(height: 1, color: Brand.fill, margin: const EdgeInsets.symmetric(vertical: 8)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total paid', style: tw(FontWeight.w900, 16)),
                        Text('£8.01', style: tw(FontWeight.w900, 20)),
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
                          const Ico('card', size: 18, color: Brand.sub),
                          const SizedBox(width: 8),
                          Text('Visa •••• 4242', style: tw(FontWeight.w700, 13, Brand.sub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(child: McGhostButton('Receipt', icon: 'receipt', height: 48)),
                  SizedBox(width: 10),
                  Expanded(child: McGhostButton('Get help', icon: 'msg', height: 48)),
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
  const _FareRow(this.label, this.amount, {this.value = Brand.ink});
  final String label;
  final String amount;
  final Color value;

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
