import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/widgets/mc.dart';
import '../../../core/widgets/current_location_map.dart';
import '../models/trip_status.dart';
import '../providers/ride_flow_notifier.dart';
import '../services/live_nearby_cars.dart';
import '../services/nearby_drivers_service.dart';
import '../services/saved_places_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Live nearby drivers from the API (Redis GEO), polled around the user and
  /// interpolated between polls. Held in a notifier rather than in setState:
  /// the cars move ~12×/s, and only the map layer should repaint at that rate —
  /// not the "Where to?" sheet underneath it.
  final ValueNotifier<Set<Marker>> _carMarkers = ValueNotifier(const {});

  late final LiveNearbyCars _cars = LiveNearbyCars(
    onUpdate: (markers) => _carMarkers.value = markers,
    service: ref.read(nearbyDriversServiceProvider),
  );

  @override
  void initState() {
    super.initState();
    _resumeActiveTrip();
  }

  /// A rider whose app was killed mid-ride lands here, not on their tracking
  /// map — the trip is still running server-side but the client forgot it.
  /// Re-attach and send them back to the screen matching its status.
  Future<void> _resumeActiveTrip() async {
    final trip = await ref.read(rideFlowProvider.notifier).resumeActiveTrip();
    if (trip == null || !mounted) return;

    final destination = switch (trip.status) {
      TripStatus.requested => '/searching',
      TripStatus.driverAssigned || TripStatus.driverArrived => '/tracking',
      TripStatus.inProgress => '/in-progress',
      _ => null,
    };
    if (destination != null) context.go(destination);
  }

  @override
  void dispose() {
    _cars.stop();
    _carMarkers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<Set<Marker>>(
              valueListenable: _carMarkers,
              builder: (context, cars, _) => CurrentLocationMap(
                markers: cars,
                onLocated: _cars.start,
                // Follow the map: pan to another part of town and the cars shown
                // are the ones actually there, sized to what's on screen.
                onCameraSettled: (center, visibleRadius) => _cars.recenter(
                  center,
                  radiusMeters: visibleRadius.clamp(1000.0, 25000.0),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 58,
            left: 16,
            child: McMenuButton(),
          ),
          Positioned(
            top: 58,
            right: 16,
            child: McCircleButton('user', onTap: () => context.go('/account')),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: McSheet(
              height: 392,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const McTitle('Where to?', size: 22),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Ico('clock', size: 16, color: Brand.sub),
                          const SizedBox(width: 5),
                          Text('Now', style: tw(FontWeight.w700, 13, Brand.sub)),
                          const SizedBox(width: 2),
                          const Ico('chevD', size: 14, color: Brand.sub),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  McField(
                    icon: 'search',
                    placeholder: 'Enter destination',
                    onTap: () => context.push('/set-route'),
                  ),
                  const SizedBox(height: 14),
                  Consumer(
                    builder: (context, ref, _) {
                      final saved = ref.watch(savedPlacesNotifierProvider);
                      final homePlace = saved.home;
                      final workPlace = saved.work;

                      return Column(
                        children: [
                          _SavedRow(
                            icon: 'home',
                            title: 'Home',
                            sub: homePlace != null
                                ? (homePlace.address.isNotEmpty
                                    ? homePlace.address
                                    : homePlace.label)
                                : 'Set home address',
                            divider: true,
                            onTap: () {
                              if (homePlace != null) {
                                context.push('/route-preview', extra: homePlace);
                              } else {
                                context.push('/set-route');
                              }
                            },
                          ),
                          _SavedRow(
                            icon: 'heart',
                            title: 'Work',
                            sub: workPlace != null
                                ? (workPlace.address.isNotEmpty
                                    ? workPlace.address
                                    : workPlace.label)
                                : 'Set work address',
                            divider: true,
                            onTap: () {
                              if (workPlace != null) {
                                context.push('/route-preview', extra: workPlace);
                              } else {
                                context.push('/set-route');
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  _SavedRow(
                    icon: 'clock',
                    title: 'Aldgate Station',
                    sub: 'Recent · 2.1 mi',
                    divider: false,
                    onTap: () => context.push('/set-route'),
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

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.divider,
    this.onTap,
  });
  final String icon;
  final String title;
  final String sub;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: Brand.fill))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: Brand.fill, shape: BoxShape.circle),
              child: Center(child: Ico(icon, size: 19, color: Brand.sub)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tw(FontWeight.w800, 15)),
                  Text(sub, style: tw(FontWeight.w600, 12.5, Brand.sub)),
                ],
              ),
            ),
            const Ico('chevR', size: 18, color: Brand.faint),
          ],
        ),
      ),
    );
  }
}
