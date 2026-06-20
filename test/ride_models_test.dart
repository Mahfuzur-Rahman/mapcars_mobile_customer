// Unit tests for the ride domain models: money formatting, status parsing,
// and flexible Trip deserialization (nested vs. the backend's flat shape).

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/utils/money.dart';
import 'package:mapcars_mobile/src/features/ride/models/ride_option.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip_status.dart';

void main() {
  test('formatGbp renders pence as a GBP string', () {
    expect(formatGbp(890), '£8.90');
    expect(formatGbp(2100), '£21.00');
    expect(formatGbp(0), '£0.00');
  });

  group('RideOption.fromJson', () {
    test('reads pricePence directly', () {
      final o = RideOption.fromJson({
        'id': 'economy',
        'name': 'Economy',
        'etaMinutes': 3,
        'pricePence': 890,
      });
      expect(o.formattedPrice, '£8.90');
      expect(o.formattedEta, '3 min away');
    });

    test('falls back to a decimal "price" field', () {
      final o = RideOption.fromJson({'id': 'x', 'name': 'X', 'price': 8.9});
      expect(o.pricePence, 890);
    });
  });

  group('TripStatus.fromApi', () {
    test('maps the integer wire form 1:1 with the backend enum', () {
      expect(TripStatus.fromApi(0), TripStatus.requested);
      expect(TripStatus.fromApi(3), TripStatus.inProgress);
      expect(TripStatus.fromApi(4), TripStatus.completed);
      expect(TripStatus.fromApi(99), TripStatus.unknown);
    });

    test('maps the string wire form', () {
      expect(TripStatus.fromApi('InProgress'), TripStatus.inProgress);
      expect(TripStatus.fromApi('CancelledByRider'), TripStatus.cancelledByRider);
    });

    test('classifies active and cancelled states', () {
      expect(TripStatus.inProgress.isActive, isTrue);
      expect(TripStatus.completed.isActive, isFalse);
      expect(TripStatus.cancelledByDriver.isCancelled, isTrue);
    });
  });

  group('Trip.fromJson', () {
    test('parses the backend flat shape with a decimal fare', () {
      final t = Trip.fromJson({
        'id': 'abc',
        'status': 4,
        'pickupAddress': '40 Canary Wharf',
        'pickupLat': 51.5,
        'pickupLng': -0.02,
        'dropoffAddress': 'Tower Bridge',
        'dropoffLat': 51.5,
        'dropoffLng': -0.07,
        'fareAmount': 8.01,
      });
      expect(t.status, TripStatus.completed);
      expect(t.pickup.address, '40 Canary Wharf');
      expect(t.formattedFare, '£8.01');
    });

    test('parses a nested shape with integer pence', () {
      final t = Trip.fromJson({
        'id': 'def',
        'status': 'DriverAssigned',
        'pickup': {'label': 'A', 'address': 'A', 'lat': 1.0, 'lng': 2.0},
        'dropoff': {'label': 'B', 'address': 'B', 'lat': 3.0, 'lng': 4.0},
        'farePence': 1240,
        'pin': '4821',
      });
      expect(t.status, TripStatus.driverAssigned);
      expect(t.pickup.label, 'A');
      expect(t.formattedFare, '£12.40');
      expect(t.pin, '4821');
    });
  });
}
