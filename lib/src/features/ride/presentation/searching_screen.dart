import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../../../core/widgets/map_background.dart';
import '../models/ride_option.dart';
import '../models/trip_status.dart';
import '../providers/ride_flow_notifier.dart';

/// Shown right after booking while the broadcast dispatch looks for a driver.
/// Reacts to the real trip: once `activeTrip.status` leaves `requested` (a
/// driver accepted), it moves on to `/tracking`. With no active trip (e.g. the
/// dev screen-stepper walkthrough), it just shows the static content below.
class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key});

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    if (_cancelling) return;
    if (ref.read(rideFlowProvider).activeTrip == null) {
      context.go('/home');
      return;
    }
    setState(() => _cancelling = true);
    await ref.read(rideFlowProvider.notifier).cancelActiveTrip();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(rideFlowProvider);
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

    RideOption? option;
    final quote = ref.watch(rideQuoteProvider).asData?.value;
    for (final o in quote?.options ?? const <RideOption>[]) {
      if (o.id == flow.selectedOptionId) {
        option = o;
        break;
      }
    }
    final trip = flow.activeTrip;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapBackground(
              route: false,
              markers: [
                MapMarker(
                  0.46,
                  0.40,
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _pulse(150, 0.08),
                        _pulse(100, 0.13),
                        _pulse(60, 0.20),
                        const MapPin(dest: false),
                      ],
                    ),
                  ),
                ),
              ],
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
                              Text(option?.name ?? 'Economy', style: tw(FontWeight.w800, 14)),
                              Text(
                                trip?.formattedFare ?? '£8.01',
                                style: tw(FontWeight.w600, 12, Brand.sub),
                              ),
                            ],
                          ),
                        ),
                        Text(trip?.pickup.label ?? 'Tower Bridge',
                            style: tw(FontWeight.w700, 12, Brand.sub)),
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

  Widget _pulse(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Brand.blue.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );
}
