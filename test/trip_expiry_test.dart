// Unit tests for the request-expiry client logic: parsing the server's search
// window, the countdown's clock-skew correction, and its formatting.
//
// The rules that actually decide whether a request is still live live on the
// server. What is tested here is the part that can be wrong without anyone
// noticing: a customer being shown the wrong number of seconds.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/utils/server_clock.dart';
import 'package:mapcars_mobile/src/core/widgets/countdown.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip_status.dart';

void main() {
  group('TripStatus.fromApi', () {
    test('parses Expired from the string wire form', () {
      expect(TripStatus.fromApi('Expired'), TripStatus.expired);
      expect(TripStatus.fromApi('expired'), TripStatus.expired);
    });

    test('parses Expired from the int wire form', () {
      expect(TripStatus.fromApi(7), TripStatus.expired);
    });

    test('never resolves a wire value to the unknown sentinel', () {
      // `unknown` is this client's own marker for "the server said something we
      // don't recognise". If an int could land on it, a future status would be
      // silently mistaken for a parse failure — and vice versa.
      expect(TripStatus.fromApi(TripStatus.unknown.index), TripStatus.unknown);
      expect(TripStatus.fromApi(99), TripStatus.unknown);
      expect(TripStatus.fromApi('somethingNew'), TripStatus.unknown);
    });

    test('expired is an ending, but not a cancellation', () {
      expect(TripStatus.expired.isOver, isTrue);
      expect(TripStatus.expired.isCancelled, isFalse);
      expect(TripStatus.expired.isActive, isFalse);
      expect(TripStatus.cancelledByCustomer.isOver, isTrue);
    });
  });

  group('Trip.fromJson', () {
    test('reads the search window', () {
      final trip = Trip.fromJson({
        'id': 't1',
        'status': 'Requested',
        'expiresAtUtc': '2026-09-07T10:03:00Z',
        'extensionCount': 1,
        'canExtend': true,
      });

      expect(trip.expiresAt, DateTime.utc(2026, 9, 7, 10, 3));
      expect(trip.extensionCount, 1);
      expect(trip.canExtend, isTrue);
    });

    test('defaults safely for a trip with no window', () {
      // Trips booked before the column existed, and every historical trip in
      // the records list.
      final trip = Trip.fromJson({'id': 't1', 'status': 'Completed'});
      expect(trip.expiresAt, isNull);
      expect(trip.extensionCount, 0);
      expect(trip.canExtend, isFalse);
    });
  });

  group('ServerClock', () {
    tearDown(() => ServerClock.offsetForTest = Duration.zero);

    test('counts down on the server clock, not the device clock', () {
      // A phone running two minutes fast. The deadline is 60s away on the
      // server, so that is what the customer must see — the naive device-clock
      // answer here would be a countdown that already hit zero.
      ServerClock.offsetForTest = const Duration(minutes: -2);
      final deadline = DateTime.now().toUtc().subtract(const Duration(seconds: 60));

      final left = ServerClock.remainingUntil(deadline);
      expect(left.inSeconds, closeTo(60, 1));
    });

    test('clamps a passed deadline to zero rather than going negative', () {
      final past = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      expect(ServerClock.remainingUntil(past), Duration.zero);
    });

    test('treats a missing deadline as elapsed', () {
      expect(ServerClock.remainingUntil(null), Duration.zero);
    });

    test('ignores an unparseable Date header instead of throwing', () {
      ServerClock.offsetForTest = const Duration(seconds: 30);
      ServerClock.syncFrom('not a date');
      ServerClock.syncFrom(null);

      // Last good offset survives: the server is 30s ahead of this device, so a
      // deadline 60s out by the device clock is only 30s away in reality.
      final deadline = DateTime.now().toUtc().add(const Duration(seconds: 60));
      expect(ServerClock.remainingUntil(deadline).inSeconds, closeTo(30, 1));
    });
  });

  group('formatCountdown', () {
    test('renders m:ss', () {
      expect(formatCountdown(const Duration(minutes: 2, seconds: 5)), '2:05');
      expect(formatCountdown(const Duration(seconds: 59)), '0:59');
      expect(formatCountdown(Duration.zero), '0:00');
    });

    test('floors part-seconds instead of rounding up', () {
      // Rounding up would show 3:00 for a window that is already running out,
      // and the last visible second would be 0:01 followed by a jump to nothing.
      expect(formatCountdown(const Duration(milliseconds: 1900)), '0:01');
    });

    test('shows zero for an already-elapsed duration', () {
      expect(formatCountdown(const Duration(seconds: -5)), '0:00');
    });
  });
}
