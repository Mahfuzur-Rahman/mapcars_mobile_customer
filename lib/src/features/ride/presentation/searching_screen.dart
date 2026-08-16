import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../models/trip.dart';
import '../models/trip_status.dart';
import '../providers/ride_flow_notifier.dart';
import 'widgets/static_route_map.dart';

/// Shown right after booking while the broadcast dispatch looks for a driver.
/// Reacts to the real trip: once `activeTrip.status` leaves `requested` (a
/// driver accepted), it moves on to `/tracking`.
class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key, required this.trip});

  /// The booked trip — always a real one, supplied by `RideGate`.
  final Trip trip;

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    await ref.read(rideFlowProvider.notifier).cancelActiveTrip();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    ref.listen<RideFlowState>(rideFlowProvider, (previous, next) {
      final status = next.activeTrip?.status;
      if (status == null) return;
      // A cancelled/expired search also satisfies `!= requested` — check this
      // first, otherwise the rider gets routed to /tracking for a trip that's
      // no longer live instead of seeing a cancellation message.
      if (status.isCancelled) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Your ride was cancelled.')));
        context.go('/home');
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
            child: McSheet(
              height: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Everything here is the booked trip's own record — the tier
                  // and fare the API priced, and the pickup it will collect
                  // from.
                  McCard(
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
                                Text(trip.tierLabel,
                                    style: tw(FontWeight.w800, 14)),
                              Text(
                                trip.formattedTotal ??
                                    trip.formattedFare ??
                                    'Pricing…',
                                style: tw(FontWeight.w600, 12, Brand.sub),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(trip.pickup.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: tw(FontWeight.w700, 12, Brand.sub)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  McGhostButton(
                    _cancelling ? 'Cancelling…' : 'Cancel request',
                    onTap: _cancelling ? null : _cancel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
