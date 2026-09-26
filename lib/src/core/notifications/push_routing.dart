import '../../features/ride/models/trip_status.dart';

/// Where tapping a notification should take the customer, and which trip it is
/// about. Deliberately just a route plus an id: the ride screens take no trip
/// parameter (`RideGate` resolves the customer's own ride), so opening "that
/// trip" means bringing the ride flow up to date with it and then going to one
/// of the existing routes.
class PushTarget {
  const PushTarget(this.route, {required this.tripId});

  final String route;
  final String tripId;

  @override
  bool operator ==(Object other) =>
      other is PushTarget && other.route == route && other.tripId == tripId;

  @override
  int get hashCode => Object.hash(route, tripId);

  @override
  String toString() => 'PushTarget($route, trip $tripId)';
}

/// The screen that shows a trip in [status] — the same mapping the ride
/// screens follow when they learn of a status change over realtime: an ending
/// that isn't a completed ride lands on home.
///
/// Null for [TripStatus.unknown]: guessing a screen for a status this build
/// doesn't understand is how a tap ends up somewhere broken.
String? routeForTripStatus(TripStatus status) => switch (status) {
      TripStatus.requested => '/searching',
      TripStatus.driverAssigned || TripStatus.driverArrived => '/tracking',
      TripStatus.inProgress => '/in-progress',
      TripStatus.completed => '/completed',
      TripStatus.cancelledByCustomer ||
      TripStatus.cancelledByDriver ||
      TripStatus.expired =>
        '/home',
      TripStatus.unknown => null,
    };

/// Decides where a tapped notification goes from its `data` payload alone.
///
/// Every push the API sends a customer carries a `type` and a `tripId`
/// (`TripService.TripData`, `MessageService`, `DispatchLifecycleService`), and
/// the app's own trip alerts reuse the same shape. Anything else — an unknown
/// type, a missing id, a status this build doesn't know — returns null, which
/// means "just open the app": a tap must never crash or land on a dead route.
PushTarget? pushTargetFor(Map<String, dynamic> data) {
  final tripId = data['tripId']?.toString().trim();
  if (tripId == null || tripId.isEmpty) return null;

  final route = switch (data['type']) {
    'tripStatus' => routeForTripStatus(TripStatus.fromApi(data['status'])),
    'messageReceived' => '/chat',
    // The "keep searching?" prompt lives on the searching screen.
    'tripExpiring' => '/searching',
    // The trip is over; there is nothing of it left to show.
    'tripExpired' => '/home',
    _ => null,
  };
  return route == null ? null : PushTarget(route, tripId: tripId);
}

/// Re-aims [target] at where its trip actually is by the time the tap is
/// handled. A notification is a snapshot: "driver assigned" tapped ten minutes
/// later may be about a ride that is now in progress, or already cancelled, and
/// the ride screens only react to *changes* — land one on a status it has
/// already moved past and it sits there stale.
///
/// [now] is the trip's freshly-read status, or null when it couldn't be read
/// (offline), in which case the payload's own route is the best there is.
String settledPushRoute(PushTarget target, TripStatus? now) {
  if (now == null) return target.route;
  final live = routeForTripStatus(now);
  if (live == null) return target.route;
  // Chat is still worth opening while there is a driver to talk to; once the
  // ride has ended, the ending is what the customer needs to see.
  if (target.route == '/chat' && now.isActive) return '/chat';
  return live;
}
