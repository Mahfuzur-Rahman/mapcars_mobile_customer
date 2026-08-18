// Regression tests for the arrival-notification failure.
//
// The bug: a rider's awareness of their trip hung entirely off one SignalR
// connection. `refreshActiveTrip` existed as a stated fallback but **nothing
// ever called it**, so when the socket went quiet — which in production it did,
// once a minute, when the proxy cut every long-poll with a 504 — the rider sat
// on "Finding your driver…" with a car outside and never saw the PIN.
//
// These tests pin the two properties that fix it: the REST path actually runs
// and surfaces an arrival, and the milestone is announced exactly once no matter
// how many paths deliver it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/notifications/trip_alerts.dart';
import 'package:mapcars_mobile/src/features/ride/models/chat_message.dart';
import 'package:mapcars_mobile/src/features/ride/models/driver_location.dart';
import 'package:mapcars_mobile/src/features/ride/models/place.dart';
import 'package:mapcars_mobile/src/features/ride/models/ride_quote.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip_status.dart';
import 'package:mapcars_mobile/src/features/ride/providers/ride_flow_notifier.dart';
import 'package:mapcars_mobile/src/features/ride/services/ride_service.dart';

const _tripId = 'trip-1';

Trip _trip(TripStatus status) => Trip.fromJson({
      'id': _tripId,
      'status': status.name,
      'pickup': {'label': 'Kings Cross', 'lat': 51.5308, 'lng': -0.1238},
      'dropoff': {'label': 'Soho', 'lat': 51.5136, 'lng': -0.1365},
      'pin': '4821',
    });

/// A repository whose `getTrip` answer can be changed mid-test, standing in for
/// the API moving the trip on while the rider's socket is dead.
class _FakeRepo implements RideRepository {
  _FakeRepo(this.current);
  Trip current;
  int getTripCalls = 0;

  @override
  Future<Trip> getTrip(String id) async {
    getTripCalls++;
    return current;
  }

  @override
  Future<Trip> requestTrip({
    required Place pickup,
    required Place dropoff,
    required String rideOptionId,
    required double distanceMiles,
    required int durationMinutes,
    String? promoCode,
    String? paymentMethod,
    String? paymentMethodId,
    double tipAmount = 0,
  }) async =>
      current;

  @override
  Future<DriverLocation?> driverLocation(String tripId) async => null;

  @override
  Future<Trip?> getActiveTrip() async => current;

  // Unused by these tests.
  @override
  Future<Trip> cancelTrip(String id, {String? reason}) async => current;
  @override
  Future<List<ChatMessage>> getMessages(String tripId) async => const [];
  @override
  Future<RideQuote> quote({required Place pickup, required Place dropoff}) =>
      throw UnimplementedError();
  @override
  Future<List<Place>> searchPlaces(String query) async => const [];
  @override
  Future<ChatMessage> sendMessage(String tripId, {required String content}) =>
      throw UnimplementedError();
  @override
  Future<void> submitRating(String tripId,
      {required int score, String? comment}) async {}
  @override
  Future<List<Trip>> tripHistory() async => [current];
}

/// Records the alerts that would have been raised, without touching the
/// notification platform channel.
class _SpyAlerts extends TripAlerts {
  final List<String> raised = [];

  @override
  Future<void> driverArrived({String? driverName, String? pin}) async {
    raised.add('arrived:$pin');
  }

  @override
  Future<void> driverOnTheWay({String? driverName, String? etaLabel}) async {
    raised.add('onTheWay');
  }
}

/// Puts the notifier in the state the confirm screen would leave it in: a route
/// set and a tier chosen, so [RideFlowNotifier.confirmTrip] actually books.
Future<void> _book(RideFlowNotifier notifier) async {
  notifier.setRoute(
    pickup: const Place(
        label: 'Kings Cross', address: 'London N1C', lat: 51.5308, lng: -0.1238),
    dropoff: const Place(
        label: 'Soho', address: 'London W1D', lat: 51.5136, lng: -0.1365),
    distanceMiles: 2.4,
    durationMinutes: 12,
  );
  notifier.selectOption('economy');
  await notifier.confirmTrip();
}

({ProviderContainer container, _FakeRepo repo, _SpyAlerts alerts}) _harness(
    Trip initial) {
  final repo = _FakeRepo(initial);
  final alerts = _SpyAlerts();
  final container = ProviderContainer(overrides: [
    rideRepositoryProvider.overrideWithValue(repo),
    tripAlertsProvider.overrideWithValue(alerts),
  ]);
  addTearDown(container.dispose);
  return (container: container, repo: repo, alerts: alerts);
}

void main() {
  test('the REST fallback surfaces an arrival the socket never delivered',
      () async {
    final h = _harness(_trip(TripStatus.requested));
    final notifier = h.container.read(rideFlowProvider.notifier);

    // Booked, and as far as this rider's app knows the trip is still unassigned:
    // no realtime token in this harness, so nothing can arrive by push.
    await _book(notifier);
    expect(h.container.read(rideFlowProvider).activeTrip?.status,
        TripStatus.requested);

    // Meanwhile the driver accepted and pulled up.
    h.repo.current = _trip(TripStatus.driverArrived);

    await notifier.refreshActiveTrip();

    expect(h.container.read(rideFlowProvider).activeTrip?.status,
        TripStatus.driverArrived,
        reason: 'the rider must learn about the arrival over REST alone');
    expect(h.alerts.raised, ['arrived:4821'],
        reason: 'and be told, with the PIN the driver will ask for');
  });

  test('an arrival is announced once even when several paths deliver it',
      () async {
    final h = _harness(_trip(TripStatus.driverArrived));
    final notifier = h.container.read(rideFlowProvider.notifier);

    await _book(notifier);
    // Three more sightings of the same arrival — a poll landing on top of a
    // push, then a resume re-reading it.
    await notifier.refreshActiveTrip();
    await notifier.refreshActiveTrip();
    await notifier.resumeTrip(_trip(TripStatus.driverArrived));

    expect(h.alerts.raised.where((a) => a.startsWith('arrived')).length, 1,
        reason: 'the rider should be interrupted once, not once per delivery');
  });

  test('the watchdog polls on its own while realtime is unavailable', () async {
    final h = _harness(_trip(TripStatus.requested));
    final notifier = h.container.read(rideFlowProvider.notifier);

    await _book(notifier);
    final callsAfterBooking = h.repo.getTripCalls;

    h.repo.current = _trip(TripStatus.driverArrived);
    // Longer than the 3s offline cadence: nobody calls refreshActiveTrip here,
    // so anything that changes had to come from the watchdog itself. This is the
    // exact property that was missing — the fallback was dead code.
    await Future<void>.delayed(const Duration(seconds: 5));

    expect(h.repo.getTripCalls, greaterThan(callsAfterBooking),
        reason: 'the safety net must poll without a screen asking it to');
    expect(h.container.read(rideFlowProvider).activeTrip?.status,
        TripStatus.driverArrived);
    expect(h.alerts.raised, contains('arrived:4821'));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
