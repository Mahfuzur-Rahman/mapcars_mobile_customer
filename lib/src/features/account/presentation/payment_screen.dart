import 'package:flutter/material.dart';

import '../../../core/widgets/mc.dart';

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
              const McTitle('Payment', size: 26),
              const SizedBox(height: 16),
              _sectionLabel('CARDS'),
              const SizedBox(height: 10),
              _cardRow(
                brand: 'Visa',
                number: '•••• 4242',
                expires: 'Expires 04/28',
                chipGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Brand.blue, Brand.blueDeep],
                ),
                isDefault: true,
              ),
              const SizedBox(height: 10),
              _cardRow(
                brand: 'Mastercard',
                number: '•••• 8801',
                expires: 'Expires 05/28',
                chipGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B6370), Color(0xFF3A4250)],
                ),
                isDefault: false,
              ),
              const SizedBox(height: 22),
              _sectionLabel('ADD A CARD'),
              const SizedBox(height: 10),
              const McField(
                  icon: 'card',
                  placeholder: 'Card number',
                  editable: true,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(
                      child: McField(
                          placeholder: 'MM / YY',
                          editable: true,
                          keyboardType: TextInputType.datetime)),
                  SizedBox(width: 10),
                  Expanded(
                      child: McField(
                          placeholder: 'CVC',
                          editable: true,
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 18),
              const McButton('Add card', icon: 'plus'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      Text(text, style: tw(FontWeight.w800, 12, Brand.sub, 0.5));

  Widget _cardRow({
    required String brand,
    required String number,
    required String expires,
    required Gradient chipGradient,
    required bool isDefault,
  }) {
    return McCard(
      padding: 14,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 30,
            decoration: BoxDecoration(
              gradient: chipGradient,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Center(child: Ico('card', size: 18, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$brand $number', style: tw(FontWeight.w900, 14.5)),
                Text(expires, style: tw(FontWeight.w600, 12, Brand.sub)),
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Brand.green.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('Default', style: tw(FontWeight.w800, 11, Brand.green)),
            )
          else
            const Ico('chevR', size: 18, color: Brand.faint),
        ],
      ),
    );
  }
}
