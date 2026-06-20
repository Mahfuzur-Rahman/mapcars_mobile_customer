import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  int _rating = 4;
  int _tip = 1; // index into _tips; default selects £2 (green).

  static const List<String> _tips = ['£1', '£2', '£5', 'Other'];

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
              const McTitle('Rate your driver', size: 23, align: TextAlign.center),
              const SizedBox(height: 18),
              Column(
                children: [
                  const McAvatar(size: 76, color: Brand.blue),
                  const SizedBox(height: 6),
                  Text('James K.', style: tw(FontWeight.w900, 17)),
                  const SizedBox(height: 2),
                  Text('Silver Toyota Prius', style: tw(FontWeight.w600, 13, Brand.sub)),
                ],
              ),
              const SizedBox(height: 18),
              // Stars.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++) ...[
                    GestureDetector(
                      onTap: () => setState(() => _rating = i),
                      child: Ico(
                        i <= _rating ? 'starF' : 'star',
                        size: 38,
                        color: i <= _rating ? Brand.star : Brand.line,
                      ),
                    ),
                    if (i != 5) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              // Tip card.
              McCard(
                padding: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add a tip', style: tw(FontWeight.w900, 15)),
                    const SizedBox(height: 2),
                    Text('100% goes to James', style: tw(FontWeight.w600, 12.5, Brand.sub)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (int i = 0; i < _tips.length; i++) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _tip = i),
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _tip == i ? Brand.green.withValues(alpha: 0.07) : Brand.paper,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: _tip == i ? Brand.green : Brand.line,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  _tips[i],
                                  style: tw(FontWeight.w900, 15, _tip == i ? Brand.green : Brand.ink),
                                ),
                              ),
                            ),
                          ),
                          if (i != _tips.length - 1) const SizedBox(width: 9),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const McField(icon: 'edit', placeholder: 'Leave a compliment…'),
              const SizedBox(height: 18),
              McButton(
                'Submit · £2.00 tip',
                icon: 'check',
                kind: BtnKind.green,
                onTap: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
