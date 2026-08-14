import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/nav.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';
import '../models/ride_option.dart';
import '../providers/ride_flow_notifier.dart';

/// Final booking step: shows the chosen ride + a tip selector (attract drivers in
/// the broadcast model), then books the trip for real via the ride flow and heads
/// to the searching screen.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key});

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  static const _tipOptions = [0, 1, 2, 5]; // whole pounds
  int _tipPounds = 0;
  String _method = 'cash'; // 'cash' works today; 'card' (Stripe) lands next
  bool _submitting = false;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final trip = await ref
        .read(rideFlowProvider.notifier)
        .confirmTrip(paymentMethod: _method, tipAmount: _tipPounds.toDouble());
    if (!mounted) return;
    if (trip != null) {
      context.go('/searching');
      return;
    }
    setState(() => _submitting = false);
    final err = ref.read(rideFlowProvider).error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(err ?? "Couldn't book your ride. Please try again."),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(rideFlowProvider);
    final quote = ref.watch(rideQuoteProvider);

    RideOption? option;
    for (final o in quote.asData?.value.options ?? const <RideOption>[]) {
      if (o.id == flow.selectedOptionId) {
        option = o;
        break;
      }
    }
    final farePence = option?.pricePence ?? 0;
    final totalPence = farePence + _tipPounds * 100;
    final canConfirm = option != null && !_submitting;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MapBackground(
              route: true,
              markers: [
                MapMarker(0.28, 0.80, MapPin(dest: false)),
                MapMarker(0.72, 0.26, MapPin(dest: true)),
              ],
            ),
          ),
          Positioned(
            top: 58,
            left: 16,
            right: 16,
            child: McFloatingNav(onBack: () => backOr(context, '/choose-ride')),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const McTitle('Confirm your ride', size: 19),
                    const SizedBox(height: 12),
                    McCard(
                      padding: 14,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
                                ),
                                Container(
                                  width: 2,
                                  height: 34,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: Brand.line,
                                ),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Brand.blue,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _RouteEnd(
                                  title: flow.pickup?.label ?? 'Pickup',
                                  sub: 'Pickup',
                                ),
                                const SizedBox(height: 12),
                                _RouteEnd(
                                  title: flow.dropoff?.label ?? 'Destination',
                                  sub: flow.distanceMiles != null
                                      ? 'Dropoff · ${flow.distanceMiles!.toStringAsFixed(1)} mi'
                                      : 'Dropoff',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LineRow(icon: 'car', text: option?.name ?? 'Ride', value: formatGbp(farePence)),
                    const SizedBox(height: 14),
                    Text('Add a tip to get picked up faster',
                        style: tw(FontWeight.w700, 13, Brand.sub)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final t in _tipOptions) _TipChip(
                          pounds: t,
                          selected: _tipPounds == t,
                          onTap: () => setState(() => _tipPounds = t),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Pay with', style: tw(FontWeight.w700, 13, Brand.sub)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PayOption(
                            icon: 'cash',
                            label: 'Cash',
                            selected: _method == 'cash',
                            onTap: () => setState(() => _method = 'cash'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PayOption(
                            icon: 'card',
                            label: 'Card',
                            selected: _method == 'card',
                            // Card charging (Stripe) isn't wired yet — coming next.
                            comingSoon: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: tw(FontWeight.w800, 15)),
                        Text(formatGbp(totalPence), style: tw(FontWeight.w900, 22)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    McButton(
                      _submitting ? 'Booking…' : 'Confirm MAP CARS',
                      icon: 'check',
                      kind: BtnKind.grad,
                      onTap: canConfirm ? _confirm : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({required this.pounds, required this.selected, required this.onTap});
  final int pounds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Brand.blue : Brand.fill,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            pounds == 0 ? 'None' : '+£$pounds',
            style: tw(FontWeight.w800, 13.5, selected ? Colors.white : Brand.ink),
          ),
        ),
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
    this.comingSoon = false,
  });
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final disabled = comingSoon || onTap == null;
    final fg = disabled
        ? Brand.faint
        : (selected ? Brand.blue : Brand.ink);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Brand.blue.withValues(alpha: 0.08) : Brand.fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Brand.blue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Ico(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label, style: tw(FontWeight.w800, 14, fg)),
              const Spacer(),
              if (comingSoon)
                Text('Soon', style: tw(FontWeight.w800, 10.5, Brand.faint, 0.4))
              else if (selected)
                const Ico('check', size: 16, color: Brand.blue),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteEnd extends StatelessWidget {
  const _RouteEnd({required this.title, required this.sub});
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tw(FontWeight.w800, 14)),
        Text(sub, style: tw(FontWeight.w600, 12, Brand.sub)),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.icon, required this.text, required this.value});
  final String icon;
  final String text;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Ico(icon, size: 20, color: Brand.sub),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: tw(FontWeight.w700, 14))),
        Text(value, style: tw(FontWeight.w800, 14)),
      ],
    );
  }
}
