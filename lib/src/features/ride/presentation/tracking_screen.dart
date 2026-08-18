import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../models/trip.dart';
import '../models/trip_status.dart';
import '../providers/ride_flow_notifier.dart';
import 'widgets/driver_card.dart';
import 'widgets/trip_tracking_map.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.trip});

  /// The ride being tracked — always a real one, supplied by `RideGate`.
  final Trip trip;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  TripEta? _eta;
  final ScrollController _sheetScroll = ScrollController();

  @override
  void dispose() {
    _sheetScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Seed the car's position over REST: every `driverLocation` push sent before
    // this screen mounted is gone, and without this the map has no car on it
    // until the driver's next ping.
    Future.microtask(
        () => ref.read(rideFlowProvider.notifier).refreshDriverLocation());
  }

  /// Second line of the status pill. Says how far away the driver is when we
  /// know, and admits it when the driver's position has gone stale rather than
  /// leaving a frozen car on the map implying they're still coming.
  String _subtitle({
    required bool arrived,
    required String? driverName,
    required TripEta? eta,
    required bool stale,
  }) {
    final who = driverName ?? 'Your driver';
    if (arrived) return '$who is waiting at the pickup';
    if (stale) return "$who's location is catching up…";
    if (eta != null) return '$who is ${eta.distanceLabel} away';
    return '$who is on the way';
  }

  /// Calls the driver on their real number. There is no stand-in: this used to
  /// fall back to a hard-coded London landline, so "Call" on a trip whose
  /// driver has no number dialled a stranger.
  Future<void> _makeCall(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text("Your driver's number isn't available — use Message."),
        ));
      return;
    }
    final launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not start a call to $phone')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final driverPosition =
        ref.watch(rideFlowProvider.select((s) => s.driverLocation));

    // React to the real trip: move on once the driver starts the trip, or
    // bounce home if it's cancelled out from under the rider (e.g. the driver
    // cancelled or no-showed) — the rider-initiated cancel path already
    // navigates itself (see `confirmCancelRide` below).
    ref.listen<RideFlowState>(rideFlowProvider, (previous, next) {
      final status = next.activeTrip?.status;
      if (status == TripStatus.driverArrived &&
          previous?.activeTrip?.status != TripStatus.driverArrived) {
        // The sheet may be scrolled down from reading the driver's details;
        // bring the PIN back into view rather than trusting the rider to find it.
        if (_sheetScroll.hasClients) _sheetScroll.jumpTo(0);
      }
      if (status == TripStatus.inProgress) {
        context.go('/in-progress');
      } else if (status != null &&
          status.isCancelled &&
          previous?.activeTrip?.status != status) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Your ride was cancelled.')));
        context.go('/home');
      }
    });

    final arrived = trip.status == TripStatus.driverArrived;
    final driverName = trip.driver?.name;
    final eta = _eta;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TripTrackingMap(
              driver: driverPosition,
              destination: LatLng(trip.pickup.lat, trip.pickup.lng),
              destinationLabel: trip.pickup.label,
              isPickup: true,
              onEta: (value) {
                if (mounted) setState(() => _eta = value);
              },
            ),
          ),
          // Floating status pill.
          Positioned(
            top: 56,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                McFloatingNav(onBack: () => backOr(context, '/home')),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    // Arrival is the one moment on this screen the rider has to
                    // act on, so it doesn't share the neutral en-route pill.
                    color: arrived ? Brand.green : Brand.ink,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x5216202E), blurRadius: 18, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Ico('car', size: 22, color: arrived ? Colors.white : Brand.lime),
                      const SizedBox(width: 12),
                      // Expanded, not a bare Column: a Row gives its children
                      // unbounded width, so both lines used to lay out at their
                      // natural length and overflow the pill on the right. It
                      // only showed up once a driver was assigned, because that
                      // is when the subtitle grows from "Your driver is on the
                      // way" to "<driver name> is 1.2 km away".
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              arrived
                                  ? 'Your driver has arrived'
                                  : eta == null
                                      // No position yet — don't invent a number.
                                      ? 'Your driver is on the way'
                                      : 'Arriving in ${eta.etaLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tw(FontWeight.w900, 16, Colors.white),
                            ),
                            Text(
                              _subtitle(
                                  arrived: arrived,
                                  driverName: driverName,
                                  eta: eta,
                                  stale: driverPosition?.isStale ?? false),
                              // A long name must truncate, never push the pill
                              // apart — this line is the widest thing here.
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tw(FontWeight.w600, 12, Colors.white.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
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
              child: SingleChildScrollView(
                controller: _sheetScroll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Once the driver is at the kerb the PIN is the only thing
                    // the rider needs, so it moves to the top of the sheet. It
                    // used to sit below the driver card and the meet-at row,
                    // i.e. below the fold on a small phone, at exactly the
                    // moment someone is being asked to read it out.
                    if (arrived && trip.pin != null) ...[
                      _PinCard(pin: trip.pin!, arrived: true),
                      const SizedBox(height: 12),
                    ],
                    DriverCard(
                      driver: trip.driver,
                      actions: Row(
                        children: [
                          Expanded(
                            child: _MiniButton(
                              icon: 'phone',
                              label: 'Call',
                              onTap: () =>
                                  _makeCall(context, trip.driver?.phone),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniButton(
                              icon: 'msg',
                              label: 'Message',
                              onTap: () => context.push('/chat'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                              child: _MiniButton(icon: 'shield', label: 'Safety')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Meet at ${trip.pickup.label}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tw(FontWeight.w700, 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The driver keys this in before setting off, so it has to
                    // be readable at arm's length in a car window — not a 12pt
                    // aside. Hidden when the trip predates PINs.
                    if (trip.pin case final pin? when !arrived) ...[
                      _PinCard(pin: pin, arrived: false),
                      const SizedBox(height: 12),
                    ],
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

/// Shows a "cancel this ride?" confirmation with an optional reason field,
/// then calls [RideFlowNotifier.cancelActiveTrip] — only leaving the screen
/// once the cancel actually succeeds. Shared by [TrackingScreen] and
/// [InProgressScreen] (both let the rider cancel while a trip is active).
Future<void> confirmCancelRide(BuildContext context, WidgetRef ref) async {
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel this ride?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your driver will be notified — this can't be undone."),
          const SizedBox(height: 14),
          TextField(
            controller: reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Keep ride', style: tw(FontWeight.w700, 14, Brand.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Cancel ride', style: tw(FontWeight.w800, 14, Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    reasonController.dispose();
    return;
  }
  final reason = reasonController.text.trim();
  reasonController.dispose();

  await ref.read(rideFlowProvider.notifier).cancelActiveTrip(
        reason: reason.isEmpty ? null : reason,
      );
  if (!context.mounted) return;

  final error = ref.read(rideFlowProvider).error;
  if (error != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  context.go('/home');
}

/// The rider's meet-up code. The driver types it in on their side before the
/// trip can start, which is what stops someone getting into the wrong car (or
/// the wrong passenger getting into this one).
class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin, required this.arrived});
  final String pin;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    return McCard(
      padding: 14,
      color: arrived ? Brand.blue.withValues(alpha: 0.08) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arrived
                ? 'Give your driver this PIN'
                : 'Your PIN — give it to your driver',
            style: tw(FontWeight.w700, 12.5, Brand.sub),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pin.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Container(
                  width: 46,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Brand.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(pin[i], style: tw(FontWeight.w900, 24, Brand.ink)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.label, this.onTap});
  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
      height: 46,
      decoration: BoxDecoration(color: Brand.fill, borderRadius: BorderRadius.circular(13)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Ico(icon, size: 18, color: Brand.ink),
          const SizedBox(height: 1),
          Text(label, style: tw(FontWeight.w800, 10.5, Brand.sub)),
        ],
      ),
      ),
    );
  }
}
