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

    // The primary action, pinned under the list. It exists in every state — a
    // disabled "pricing" button while loading, Retry on error — so the sheet is
    // the same height throughout and nothing jumps when the prices arrive.
    final Widget footer = quote.when(
      loading: () => const McButton('Pricing your trip…', icon: 'bolt'),
      error: (e, _) => McButton('Retry', icon: 'clock', onTap: () {
        ref.invalidate(fareChartProvider);
        ref.invalidate(rideQuoteProvider);
      }),
      data: (q) {
        final sel = q.options[_selected.clamp(0, q.options.length - 1)];
        return McButton(
          'Choose ${sel.name} · ${sel.formattedPrice}',
          icon: 'bolt',
          onTap: () {
            ref.read(rideFlowProvider.notifier).selectOption(sel.id);
            context.push('/confirm');
          },
        );
      },
    );

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
              // A cap, not a size: the sheet fits its content up to here, so
              // the route stays in view above it. McSheet spends
              // 12 + max(28, 12 + bottom inset) on padding and 19 on its handle,
              // and the pinned button takes 12 + 54 more, which leaves
              // _pricedBodyHeight (304) for today's 4-tier chart. With a 48dp
              // nav-bar inset that is 31 + 304 + 66 + 60 = 461; 480 adds slack
              // for font metrics, so the four tiers show without scrolling on a
              // 360x640 phone. A fifth tier or larger text makes the *list*
              // scroll inside the sheet — the button stays where it is — and
              // McSheet holds this to 85% of a short screen regardless.
              maxHeight: 480,
              footer: footer,
              child: quote.when(
                loading: () => const _PlaceholderBody(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => _PlaceholderBody(
                  child: Text('Could not price this trip.',
                      textAlign: TextAlign.center,
                      style: tw(FontWeight.w700, 14, Brand.sub)),
                ),
                data: (q) => _RideList(
                  quote: q,
                  selected: _selected.clamp(0, q.options.length - 1),
                  onSelect: (i) => setState(() => _selected = i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// What the priced list is made of, for sizing the loading and error states to
// match it. These mirror the layout below: change one and change the other.
const double _headerHeight = 27 + 3 + 18 + 12; // title, gap, summary, gap
const double _rowHeight = 56;
const double _rowGap = 6;
// The selected row's border is 2dp, the others' 1dp: 2dp taller in all.
const double _selectedRowExtra = 2;
const int _typicalTiers = 4;

/// The priced list's height with today's four tiers at normal text.
const double _pricedBodyHeight =
    _headerHeight +
        _typicalTiers * _rowHeight +
        _selectedRowExtra +
        (_typicalTiers - 1) * _rowGap;

/// Holds [child] centred in as much room as the priced list will take.
class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _pricedBodyHeight),
        child: Center(child: child),
      );
}

class _RideList extends StatelessWidget {
  const _RideList({
    required this.quote,
    required this.selected,
    required this.onSelect,
  });

  final RideQuote quote;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = quote.options;
    // The choose button is not here: it is the sheet's footer, so it stays on
    // screen whatever this list does. It used to sit under the heading, which
    // kept it out of the way of a short list but scrolled it out of view with
    // the first rows as soon as the list outgrew the sheet (larger text, a
    // fifth tier).
    //
    // The rows are sized so the whole set is visible at once — see _RideRow.
    // McSheet scrolls the list as a safety net for a very small screen or a
    // fare chart with more tiers than today's, but in the normal case it never
    // scrolls.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const McTitle('Choose a ride', size: 19),
        const SizedBox(height: 3),
        Text(quote.summary, style: tw(FontWeight.w600, 12.5, Brand.sub)),
        const SizedBox(height: 12),
        for (int i = 0; i < options.length; i++) ...[
          _RideRow(
            ride: options[i],
            selected: i == selected,
            onTap: () => onSelect(i),
          ),
          if (i < options.length - 1) const SizedBox(height: _rowGap),
        ],
        // The payment method and any promo are chosen on the confirm screen,
        // against the real booking. What sat here was a fixed "•••• 4242"
        // card and a promo link that did nothing.
      ],
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
