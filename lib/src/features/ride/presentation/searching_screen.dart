import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/nav.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/mc.dart';
import '../models/trip.dart';
import '../models/trip_status.dart';
import '../providers/ride_flow_notifier.dart';
import 'widgets/static_route_map.dart';

/// Shown right after booking while the broadcast dispatch looks for a driver.
/// Reacts to the real trip: once `activeTrip.status` leaves `requested` (a
/// driver accepted), it moves on to `/tracking`.
///
/// A request is not open forever. It carries a server-set deadline
/// (`expiresAtUtc`), and when that passes the search is *paused*: it comes off
/// every driver's board and the customer is asked whether to keep looking. Say
/// nothing and the trip closes itself a minute later, which is the whole point
/// — before this, an unwanted request sat here spinning indefinitely.
class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key, required this.trip});

  /// The booked trip — always a real one, supplied by `RideGate`.
  final Trip trip;

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen> {
  /// Mirrors the server's `TripExpiry.Grace`. Display only — how long the sheet
  /// says the customer has left. The server closes the trip on its own clock
  /// whatever this says, so the two drifting apart costs a slightly wrong
  /// number, never a wrongly-live request.
  static const _grace = Duration(minutes: 1);

  bool _cancelling = false;
  bool _extending = false;

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    await ref.read(rideFlowProvider.notifier).cancelActiveTrip();
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _keepSearching() async {
    if (_extending) return;
    setState(() => _extending = true);
    final ok = await ref.read(rideFlowProvider.notifier).extendActiveTrip();
    if (!mounted) return;
    setState(() => _extending = false);

    // The server refused — the grace ran out mid-tap, or the extensions are
    // spent. It owns that call; surface its reason rather than guessing.
    if (!ok) {
      final error = ref.read(rideFlowProvider).error;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error ?? "We couldn't keep this search going."),
        ));
    }
  }

  void _leaveWith(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    context.go('/home');
  }

  /// The search found nobody. Send the customer back to the ride picker with their
  /// route still set, rather than to an empty home screen that makes them type
  /// both addresses again to ask the same question.
  ///
  /// `/choose-ride` sits behind `RouteGate`, which needs exactly that route —
  /// so fall back to home if the pickup/drop-off are somehow gone.
  void _leaveExpired() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text("No drivers were available — try booking again."),
      ));
    context.go(ref.read(rideFlowProvider).hasRoute ? '/choose-ride' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

    ref.listen<RideFlowState>(rideFlowProvider, (previous, next) {
      final status = next.activeTrip?.status;
      if (status == null) return;

      // Endings first. Both of these also satisfy `!= requested`, so checking
      // them after the tracking branch would route the customer to a live-trip
      // screen for a trip that has already finished.
      if (status.isExpired) {
        _leaveExpired();
      } else if (status.isCancelled) {
        _leaveWith('Your ride was cancelled.');
      } else if (status != TripStatus.requested) {
        context.go('/tracking');
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            // The journey actually booked, not a painted road with a pulse on
            // it. The driver's own position appears on `/tracking`, once one
            // has accepted — there is nothing to show here yet.
            child: StaticRouteMap(
              pickup: trip.pickup,
              dropoff: trip.dropoff,
              route: ref.watch(rideFlowProvider).route,
            ),
          ),
          Positioned(
            top: 58,
            left: 16,
            right: 16,
            child: McFloatingNav(onBack: () => backOr(context, '/confirm')),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ExpiryCountdown(
              deadline: trip.expiresAt,
              builder: (context, left) {
                final lapsed = left == Duration.zero;
                return McSheet(
                  height: lapsed ? 330 : 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: lapsed
                        ? _lapsed(trip)
                        : _searching(trip, left),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Still looking, with time on the clock.
  List<Widget> _searching(Trip trip, Duration left) => [
        Row(
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Brand.blue),
                backgroundColor: Brand.fill,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const McTitle('Finding your driver…', size: 19),
                  Text(
                    'Matching you with a nearby MAP CARS',
                    style: tw(FontWeight.w600, 13, Brand.sub),
                  ),
                ],
              ),
            ),
            _clock(left),
          ],
        ),
        const SizedBox(height: 18),
        _tripCard(trip),
        const SizedBox(height: 14),
        McGhostButton(
          _cancelling ? 'Cancelling…' : 'Cancel request',
          onTap: _cancelling ? null : _cancel,
        ),
      ];

  /// The window closed. Ask — and be honest that not answering ends the ride.
  List<Widget> _lapsed(Trip trip) {
    final graceLeft = trip.expiresAt == null
        ? Duration.zero
        : trip.expiresAt!.add(_grace).difference(DateTime.now().toUtc());
    final canExtend = trip.canExtend;

    return [
      Row(
        children: [
          const Ico('clock', size: 26, color: Brand.star),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                McTitle(
                  canExtend ? 'Still looking' : 'No drivers yet',
                  size: 19,
                ),
                Text(
                  canExtend
                      ? "No one has taken your ride yet. Keep searching?"
                      : "We've searched as long as we can for this ride.",
                  style: tw(FontWeight.w600, 13, Brand.sub),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // Say what happens if they do nothing. A prompt that quietly cancels the
      // ride a minute later, with no warning, is the kind of thing customers only
      // discover once it has cost them.
      Text(
        canExtend
            ? 'This ride cancels itself in ${formatCountdown(graceLeft)} '
                'if you do nothing.'
            : 'This ride will close in ${formatCountdown(graceLeft)}.',
        style: tw(FontWeight.w700, 12, Brand.faint),
      ),
      const SizedBox(height: 14),
      _tripCard(trip),
      const SizedBox(height: 14),
      if (canExtend)
        McButton(
          _extending ? 'Keeping it open…' : 'Keep searching',
          onTap: _extending ? null : _keepSearching,
        ),
      if (canExtend) const SizedBox(height: 8),
      McGhostButton(
        _cancelling ? 'Cancelling…' : 'Cancel ride',
        onTap: _cancelling ? null : _cancel,
      ),
    ];
  }

  /// The amber clock. Neutral while there's time, amber under a minute — the
  /// point at which "it's searching" turns into "it's about to stop".
  Widget _clock(Duration left) {
    final urgent = left.inSeconds <= 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: urgent ? Brand.star.withValues(alpha: 0.12) : Brand.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatCountdown(left),
        style: tw(FontWeight.w800, 13, urgent ? Brand.star : Brand.sub),
      ),
    );
  }

  /// Everything here is the booked trip's own record — the tier and fare the
  /// API priced, and the pickup it will collect from.
  Widget _tripCard(Trip trip) => McCard(
        padding: 14,
        child: Row(
          children: [
            const Ico('car', size: 22, color: Brand.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trip.tierLabel.isNotEmpty)
                    Text(trip.tierLabel, style: tw(FontWeight.w800, 14)),
                  Text(
                    trip.formattedTotal ?? trip.formattedFare ?? 'Pricing…',
                    style: tw(FontWeight.w600, 12, Brand.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                trip.pickup.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: tw(FontWeight.w700, 12, Brand.sub),
              ),
            ),
          ],
        ),
      );
}
