import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../models/trip.dart';
import '../providers/ride_flow_notifier.dart';

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key, required this.trip});

  /// The ride being rated — always a real one, supplied by `RideGate`.
  final Trip trip;

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  /// No stars until the rider picks some. It used to open on 4, so tapping
  /// straight through submitted a rating they never gave.
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tripId = widget.trip.id;
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
    final driver = widget.trip.driver;
    final tip = widget.trip.formattedTip;

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
              // The driver as recorded on the trip. Nothing invented: a trip
              // with no driver details shows none.
              Column(
                children: [
                  const McAvatar(size: 76, color: Brand.blue),
                  if (driver != null) ...[
                    const SizedBox(height: 6),
                    Text(driver.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tw(FontWeight.w900, 17)),
                    if (driver.vehicle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(driver.vehicle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tw(FontWeight.w600, 13, Brand.sub)),
                    ],
                  ],
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
              // The tip the rider actually added when booking, read-only. What
              // stood here was a £1/£2/£5 selector that charged nothing and
              // sent nothing — the tip goes on the booking, and the rating
              // endpoint takes only a score and a comment.
              if (tip != null) ...[
                McCard(
                  padding: 16,
                  child: Row(
                    children: [
                      const Ico('gift', size: 20, color: Brand.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          driver == null
                              ? 'You added a $tip tip — 100% goes to your driver'
                              : 'You added a $tip tip — 100% goes to ${driver.name}',
                          style: tw(FontWeight.w700, 13, Brand.sub),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
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
                _submitting ? 'Submitting…' : 'Submit rating',
                icon: 'check',
                kind: BtnKind.green,
                onTap: (_submitting || _rating == 0) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
