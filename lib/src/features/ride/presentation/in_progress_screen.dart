import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/widgets/mc.dart';
import '../models/trip.dart';
import '../models/trip_status.dart';
import '../providers/ride_flow_notifier.dart';
import 'tracking_screen.dart' show confirmCancelRide;
import 'widgets/driver_card.dart';
import 'widgets/trip_tracking_map.dart';

class InProgressScreen extends ConsumerStatefulWidget {
  const InProgressScreen({super.key, required this.trip});

  /// The ride under way — always a real one, supplied by `RideGate`.
  final Trip trip;

  @override
  ConsumerState<InProgressScreen> createState() => _InProgressScreenState();
}

class _InProgressScreenState extends ConsumerState<InProgressScreen> {
  TripEta? _eta;

  @override
  void initState() {
    super.initState();
    // The rider may have reopened the app mid-ride, having missed every
    // `driverLocation` push so far — seed the car's position over REST.
    Future.microtask(
        () => ref.read(rideFlowProvider.notifier).refreshDriverLocation());
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final driverPosition =
        ref.watch(rideFlowProvider.select((s) => s.driverLocation));
    final eta = _eta;

    // Move on once the driver marks the trip complete, or bounce home if it's
    // cancelled out from under the rider mid-trip (e.g. the driver no-shows
    // or cancels) — without this the rider was left staring at a stale map
    // with no explanation.
    ref.listen<RideFlowState>(rideFlowProvider, (previous, next) {
      final status = next.activeTrip?.status;
      if (status == TripStatus.completed) {
        context.go('/completed');
      } else if (status != null &&
          status.isCancelled &&
          previous?.activeTrip?.status != status) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Your ride was cancelled.')));
        context.go('/home');
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TripTrackingMap(
              driver: driverPosition,
              destination: LatLng(trip.dropoff.lat, trip.dropoff.lng),
              destinationLabel: trip.dropoff.label,
              isPickup: false,
              onEta: (value) {
                if (mounted) setState(() => _eta = value);
              },
            ),
          ),
          // Floating nav + status pill.
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mid-trip: no back (there is nothing to go back to), but the
                // menu still has to be reachable.
                const McFloatingNav(showBack: false),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Brand.ink,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x5216202E), blurRadius: 18, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Ico('car', size: 22, color: Brand.lime),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            eta == null
                                ? 'On trip'
                                : 'Arriving in ${eta.etaLabel}',
                            style: tw(FontWeight.w900, 16, Colors.white),
                          ),
                          Text(
                            eta == null
                                ? trip.dropoff.label
                                : '${eta.distanceLabel} to ${trip.dropoff.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tw(FontWeight.w600, 12, Colors.white.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Destination row.
                    Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: Brand.blue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trip.dropoff.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tw(FontWeight.w900, 15)),
                              Text('Destination', style: tw(FontWeight.w600, 12, Brand.sub)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Real progress along the route, not a painted 62%.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: SizedBox(
                            width: 90,
                            height: 6,
                            child: Stack(
                              children: [
                                Container(color: Brand.fill),
                                FractionallySizedBox(
                                  widthFactor: eta?.fraction ?? 0.0,
                                  child: Container(
                                    decoration: const BoxDecoration(gradient: Brand.grad),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DriverCard(driver: trip.driver),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: McGhostButton('Safety', icon: 'shield'),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: McGhostButton('Share trip', icon: 'nav'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    McGhostButton(
                      'Cancel ride',
                      icon: 'x',
                      onTap: () => confirmCancelRide(context, ref),
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

