import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../models/ride_option.dart';
import '../models/ride_quote.dart';
import '../providers/fare_chart_provider.dart';
import '../providers/ride_flow_notifier.dart';
import 'widgets/static_route_map.dart';

class ChooseRideScreen extends ConsumerStatefulWidget {
  const ChooseRideScreen({super.key});

  @override
  ConsumerState<ChooseRideScreen> createState() => _ChooseRideScreenState();
}

class _ChooseRideScreenState extends ConsumerState<ChooseRideScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(rideQuoteProvider);
    // Guaranteed by `RouteGate` — this screen is only reachable with a route.
    final flow = ref.watch(rideFlowProvider);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: StaticRouteMap(
              pickup: flow.pickup!,
              dropoff: flow.dropoff!,
              route: flow.route,
            ),
          ),
          Positioned(
            top: 58,
            left: 16,
            right: 16,
            child: McFloatingNav(onBack: () => backOr(context, '/set-route')),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 446,
              child: quote.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not price this trip.',
                          style: tw(FontWeight.w700, 14, Brand.sub)),
                      const SizedBox(height: 10),
                      McGhostButton('Retry', onTap: () {
                        ref.invalidate(fareChartProvider);
                        ref.invalidate(rideQuoteProvider);
                      }),
                    ],
                  ),
                ),
                data: (q) => _RideList(
                  quote: q,
                  selected: _selected.clamp(0, q.options.length - 1),
                  onSelect: (i) => setState(() => _selected = i),
                  onConfirm: (option) {
                    ref.read(rideFlowProvider.notifier).selectOption(option.id);
                    context.push('/confirm');
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideList extends StatelessWidget {
  const _RideList({
    required this.quote,
    required this.selected,
    required this.onSelect,
    required this.onConfirm,
  });

  final RideQuote quote;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<RideOption> onConfirm;

  @override
  Widget build(BuildContext context) {
    final options = quote.options;
    final sel = options[selected];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const McTitle('Choose a ride', size: 19),
          const SizedBox(height: 4),
          Text(quote.summary, style: tw(FontWeight.w600, 12.5, Brand.sub)),
          const SizedBox(height: 14),
          for (int i = 0; i < options.length; i++) ...[
            _RideRow(
              ride: options[i],
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
            if (i < options.length - 1) const SizedBox(height: 8),
          ],
          // The payment method and any promo are chosen on the confirm screen,
          // against the real booking. What sat here was a fixed "•••• 4242"
          // card and a promo link that did nothing.
          const SizedBox(height: 18),
          McButton(
            'Choose ${sel.name} · ${sel.formattedPrice}',
            icon: 'bolt',
            onTap: () => onConfirm(sel),
          ),
        ],
      ),
    );
  }
}

class _RideRow extends StatelessWidget {
  const _RideRow({required this.ride, required this.selected, this.onTap});
  final RideOption ride;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Brand.blue.withValues(alpha: 0.07) : Brand.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Brand.blue : Brand.line.withValues(alpha: 0.6),
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Brand.blue.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : Brand.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? Brand.blue.withValues(alpha: 0.12) : Brand.fill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Ico(ride.icon, size: 26, color: selected ? Brand.blue : Brand.sub),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(ride.name, style: tw(FontWeight.w900, 15.5)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Brand.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(ride.formattedEta,
                            style: tw(FontWeight.w800, 11, Brand.blue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(ride.description, style: tw(FontWeight.w600, 12, Brand.sub)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(ride.formattedPrice, style: tw(FontWeight.w900, 16, selected ? Brand.blue : Brand.ink)),
          ],
        ),
      ),
    );
  }
}
