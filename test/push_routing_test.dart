// Notification tap routing: which screen a tapped push opens.
//
// Tapping a notification used to just resume the app wherever it was. These
// pin the payload → route decision for every push the API sends a customer, and
// the rule that a payload this build doesn't understand opens nothing — a tap
// must never crash or land on a dead route.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/notifications/push_routing.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip_status.dart';

const _id = '3f2b8c1e-0000-4000-8000-000000000001';

PushTarget? _status(String status) =>
    pushTargetFor({'type': 'tripStatus', 'tripId': _id, 'status': status});

void main() {
  group('pushTargetFor', () {
    // Status strings exactly as the API writes them: `trip.Status.ToString()`.
    test('driver assigned / arrived open the tracking screen', () {
      expect(_status('DriverAssigned'), const PushTarget('/tracking', tripId: _id));
      expect(_status('DriverArrived'), const PushTarget('/tracking', tripId: _id));
    });

    test('a completed trip opens the completed screen', () {
      expect(_status('Completed'), const PushTarget('/completed', tripId: _id));
    });

    test('a driver cancellation lands on home, as the realtime path does', () {
      expect(_status('CancelledByDriver'), const PushTarget('/home', tripId: _id));
    });

    test('a chat message opens that trip\'s chat', () {
      expect(
        pushTargetFor({'type': 'messageReceived', 'tripId': _id}),
        const PushTarget('/chat', tripId: _id),
      );
    });

    test('an expiring search opens the searching screen with its prompt', () {
      expect(
        pushTargetFor({'type': 'tripExpiring', 'tripId': _id}),
        const PushTarget('/searching', tripId: _id),
      );
    });

    test('an expired search goes back to booking (home)', () {
      expect(
        pushTargetFor({'type': 'tripExpired', 'tripId': _id}),
        const PushTarget('/home', tripId: _id),
      );
    });

    test('the app\'s own trip alerts route through the same payload', () {
      // TripAlerts encodes this shape as its notification payload.
      expect(
        pushTargetFor({'type': 'tripStatus', 'tripId': _id, 'status': 'DriverArrived'}),
        const PushTarget('/tracking', tripId: _id),
      );
    });

    test('unknown or incomplete payloads open nothing', () {
      expect(pushTargetFor({}), isNull);
      expect(pushTargetFor({'type': 'somethingNew', 'tripId': _id}), isNull);
      // Driver-app types must not route anywhere in the customer app.
      expect(pushTargetFor({'type': 'tripAvailable', 'tripId': _id}), isNull);
      expect(pushTargetFor({'type': 'messageReceived'}), isNull);
      expect(pushTargetFor({'type': 'messageReceived', 'tripId': '  '}), isNull);
      expect(pushTargetFor({'type': 'tripExpired', 'tripId': null}), isNull);
      expect(pushTargetFor({'tripId': _id}), isNull);
    });

    test('a tripStatus with a missing or unrecognised status opens nothing', () {
      expect(pushTargetFor({'type': 'tripStatus', 'tripId': _id}), isNull);
      expect(_status('Teleported'), isNull);
    });
  });

  group('settledPushRoute', () {
    const assigned = PushTarget('/tracking', tripId: _id);

    test('keeps the payload route when the trip could not be re-read', () {
      expect(settledPushRoute(assigned, null), '/tracking');
      expect(settledPushRoute(assigned, TripStatus.unknown), '/tracking');
    });

    test('follows the trip to where it is now, not where the push said', () {
      // "Driver assigned" tapped after the ride has started.
      expect(settledPushRoute(assigned, TripStatus.inProgress), '/in-progress');
      // ...or after it was cancelled.
      expect(settledPushRoute(assigned, TripStatus.cancelledByDriver), '/home');
      expect(settledPushRoute(assigned, TripStatus.completed), '/completed');
    });

    test('an expiring search a driver has since taken opens tracking', () {
      const expiring = PushTarget('/searching', tripId: _id);
      expect(settledPushRoute(expiring, TripStatus.requested), '/searching');
      expect(settledPushRoute(expiring, TripStatus.driverAssigned), '/tracking');
      expect(settledPushRoute(expiring, TripStatus.expired), '/home');
    });

    test('chat stays chat while the ride is live, and yields once it ends', () {
      const chat = PushTarget('/chat', tripId: _id);
      expect(settledPushRoute(chat, TripStatus.driverArrived), '/chat');
      expect(settledPushRoute(chat, TripStatus.inProgress), '/chat');
      expect(settledPushRoute(chat, TripStatus.completed), '/completed');
      expect(settledPushRoute(chat, TripStatus.cancelledByCustomer), '/home');
    });
  });

  test('every status the app can show maps to a registered ride route', () {
    const known = {'/searching', '/tracking', '/in-progress', '/completed', '/home'};
    for (final s in TripStatus.values) {
      final route = routeForTripStatus(s);
      if (s == TripStatus.unknown) {
        expect(route, isNull);
      } else {
        expect(known, contains(route), reason: '$s → $route');
      }
    }
  });
}
