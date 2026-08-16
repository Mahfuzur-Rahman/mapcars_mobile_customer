import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/mc.dart';
import '../../models/trip.dart';
import '../../providers/ride_flow_notifier.dart';

/// Which trip a screen behind [RideGate] is about.
enum RideGateScope {
  /// The ride happening now (searching / tracking / in progress / chat).
  activeTrip,

  /// The ride that just finished (completed / rate).
  lastCompletedTrip,
}

/// Guarantees a ride screen a **real** [Trip] before it builds.
///
/// These screens used to render invented content whenever `activeTrip` was null
/// — a driver called James K. in a silver Prius, an £8.01 fare, a Canary Wharf →
/// Tower Bridge route — which is what the dev walkthrough (and any deep link or
/// restart) showed. Null now means one of two honest things: we're still asking
/// the API, or the rider genuinely has no such ride.
///
/// Resolution goes through the ride flow itself, so a ride recovered here is a
/// fully live one: [RideFlowNotifier.resumeActiveTrip] re-joins the trip's
/// realtime group and seeds the driver's position.
class RideGate extends ConsumerStatefulWidget {
  const RideGate({
    super.key,
    required this.builder,
    this.scope = RideGateScope.activeTrip,
  });

  final RideGateScope scope;
  final Widget Function(Trip trip) builder;

  @override
  ConsumerState<RideGate> createState() => _RideGateState();
}

class _RideGateState extends ConsumerState<RideGate> {
  /// Non-null only while we're resolving a trip the flow didn't already have.
  Future<Trip?>? _resolving;

  @override
  void initState() {
    super.initState();
    if (ref.read(rideFlowProvider).activeTrip == null) _resolve();
  }

  void _resolve() {
    final notifier = ref.read(rideFlowProvider.notifier);
    _resolving = switch (widget.scope) {
      RideGateScope.activeTrip => notifier.resumeActiveTrip(),
      RideGateScope.lastCompletedTrip => notifier.loadLastCompletedTrip(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Watching the trip (not just reading it once) is what keeps the child in
    // step with every realtime `tripUpdated` push.
    final trip = ref.watch(rideFlowProvider.select((s) => s.activeTrip));
    if (trip != null) return widget.builder(trip);

    final resolving = _resolving;
    if (resolving == null) return _empty();

    return FutureBuilder<Trip?>(
      future: resolving,
      builder: (context, snapshot) =>
          snapshot.connectionState == ConnectionState.done
              ? _empty()
              : const _GateMessage(
                  icon: 'car',
                  title: 'Loading your ride…',
                  body: 'Checking with Mapcars for your trip.',
                  busy: true,
                ),
    );
  }

  Widget _empty() => switch (widget.scope) {
        RideGateScope.activeTrip => _GateMessage(
            icon: 'car',
            title: 'No ride in progress',
            body: "You don't have a ride right now. Book one from home and "
                "you'll be able to track it here.",
            actionLabel: 'Book a ride',
            onRetry: () => setState(_resolve),
          ),
        RideGateScope.lastCompletedTrip => _GateMessage(
            icon: 'receipt',
            title: 'No completed rides yet',
            body: 'Your fare summary shows here once a ride has finished.',
            onRetry: () => setState(_resolve),
          ),
      };
}

/// Guards the pre-booking screens, which are about a **route** rather than a
/// trip. Choose-ride and confirm used to price a hard-coded Canary Wharf →
/// Tower Bridge journey when opened without one.
class RouteGate extends ConsumerWidget {
  const RouteGate({super.key, required this.child, this.requireOption = false});

  final Widget child;

  /// Confirm also needs a chosen tier — there's nothing to confirm without one.
  final bool requireOption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(rideFlowProvider);
    if (!flow.hasRoute) {
      return const _GateMessage(
        icon: 'pin',
        title: 'Set your route first',
        body: "Tell us where you're going and we'll price the ride.",
        actionLabel: 'Set route',
        actionRoute: '/set-route',
      );
    }
    if (requireOption && flow.selectedOptionId == null) {
      return const _GateMessage(
        icon: 'car',
        title: 'Choose a ride first',
        body: 'Pick a tier and its price, then confirm.',
        actionLabel: 'Choose ride',
        actionRoute: '/choose-ride',
      );
    }
    return child;
  }
}

/// The gates' non-content states: waiting on the API, or nothing to show.
/// Deliberately plain — this must never be mistakable for a real ride.
class _GateMessage extends StatelessWidget {
  const _GateMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.busy = false,
    this.actionLabel,
    this.actionRoute = '/home',
    this.onRetry,
  });

  final String icon;
  final String title;
  final String body;
  final bool busy;
  final String? actionLabel;
  final String actionRoute;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const McNavHeader(showBack: false),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: busy
                            ? const Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Brand.blue),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  color: Brand.fill,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Ico(icon, size: 28, color: Brand.sub),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      McTitle(title, size: 20, align: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: tw(FontWeight.w600, 14, Brand.sub),
                      ),
                    ],
                  ),
                ),
              ),
              if (onRetry != null) ...[
                McGhostButton('Try again', onTap: onRetry),
                const SizedBox(height: 10),
              ],
              McButton(
                actionLabel ?? 'Go to home',
                icon: actionLabel == null ? 'home' : 'chevR',
                onTap: () => context.go(actionRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
