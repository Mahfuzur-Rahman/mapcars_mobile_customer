import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../providers/ride_flow_notifier.dart';

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key});

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  int _rating = 4;
  int _tip = 1; // index into _tips; default selects £2 (green).
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const List<String> _tips = ['£1', '£2', '£5', 'Other'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tripId = ref.read(rideFlowProvider).activeTrip?.id;
    if (tripId == null) {
      // Reached without an active trip (e.g. via the dev stepper) — nothing
      // to rate, so just carry on home.
      context.go('/home');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final comment = _commentController.text.trim();
    final ok = await ref.read(rideFlowProvider.notifier).submitRating(
          tripId,
          score: _rating,
          comment: comment.isEmpty ? null : comment,
        );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submitting = false;
        _error = ref.read(rideFlowProvider).error ?? 'Could not submit your rating.';
      });
      return;
    }

    context.go('/home');
  }

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
              const McNavHeader(showBack: false),
              const SizedBox(height: 14),
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
              McField(
                icon: 'edit',
                placeholder: 'Leave a compliment…',
                editable: true,
                controller: _commentController,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: tw(FontWeight.w600, 13, Colors.red)),
              ],
              const SizedBox(height: 18),
              McButton(
                _submitting ? 'Submitting…' : 'Submit · £2.00 tip',
                icon: 'check',
                kind: BtnKind.green,
                onTap: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
