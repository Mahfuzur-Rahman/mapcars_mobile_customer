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
              // Sized so the whole tier list is visible without scrolling.
              // McSheet spends 40 on padding and 19 on its handle, leaving 387
              // for content; the compact layout needs ~366 for the live 4-tier
              // chart (title 26 + gap 3 + summary 17 + gap 12 + button 54 +
              // gap 12 + 4 rows at 56 + 3 gaps at 6). A fifth tier would need
              // ~62 more than that fits, so it would start scrolling again —
              // the scroll view below is kept for exactly that case.
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
    // The confirm button sits directly under the heading rather than after the
    // list. Below the tiers it was the one control that scrolled off on a small
    // phone, so the primary action was the hardest thing on the screen to
    // reach; here it never moves as the selection changes.
    //
    // The rows are sized so the whole set is visible at once — see _RideRow.
    // The scroll view stays as a safety net for a very small screen or a fare
    // chart with more tiers than today's, but in the normal case it never
    // scrolls.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const McTitle('Choose a ride', size: 19),
          const SizedBox(height: 3),
          Text(quote.summary, style: tw(FontWeight.w600, 12.5, Brand.sub)),
          const SizedBox(height: 12),
          McButton(
            'Choose ${sel.name} · ${sel.formattedPrice}',
            icon: 'bolt',
            onTap: () => onConfirm(sel),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < options.length; i++) ...[
            _RideRow(
              ride: options[i],
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
            if (i < options.length - 1) const SizedBox(height: 6),
          ],
          // The payment method and any promo are chosen on the confirm screen,
          // against the real booking. What sat here was a fixed "•••• 4242"
          // card and a promo link that did nothing.
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
    // Compact by design: the whole tier list has to be readable in one glance
    // without scrolling. The icon tile is 40 rather than 48 and the vertical
    // padding is 7 rather than 10, which takes ~20px off every row — enough for
    // the full set plus the confirm button to fit the sheet. The row is still
    // ~54px tall, comfortably above the 44px minimum touch target.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Brand.blue.withValues(alpha: 0.07) : Brand.paper,
          borderRadius: BorderRadius.circular(14),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? Brand.blue.withValues(alpha: 0.12) : Brand.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Ico(ride.icon, size: 22, color: selected ? Brand.blue : Brand.sub),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ride.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tw(FontWeight.w900, 14.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Brand.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(ride.formattedEta,
                            style: tw(FontWeight.w800, 10.5, Brand.blue)),
                      ),
                    ],
                  ),
                  Text(
                    ride.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tw(FontWeight.w600, 11.5, Brand.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(ride.formattedPrice,
                style: tw(FontWeight.w900, 15.5, selected ? Brand.blue : Brand.ink)),
          ],
        ),
      ),
    );
  }
}
