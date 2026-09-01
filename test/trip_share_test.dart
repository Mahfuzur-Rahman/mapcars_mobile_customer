// The "Share trip" message a rider sends from the Safety sheet.
//
// This is a safety feature, so the failure that matters is not a crash — it is
// a message that goes out missing the registration, or reading "London SE1 2UP
// — London SE1 2UP", or claiming to be live when it is a snapshot.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/features/ride/models/driver_info.dart';
import 'package:mapcars_mobile/src/features/ride/models/driver_location.dart';
import 'package:mapcars_mobile/src/features/ride/models/place.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip_status.dart';
import 'package:mapcars_mobile/src/features/ride/presentation/widgets/trip_safety.dart';

Trip _trip({DriverInfo? driver, Place? pickup, Place? dropoff}) => Trip(
      id: 't1',
      status: TripStatus.inProgress,
      pickup: pickup ??
          const Place(
            label: 'Tower Bridge',
            address: 'London SE1 2UP',
            lat: 51.5055,
            lng: -0.0754,
          ),
      dropoff: dropoff ??
          const Place(
            label: 'Kings Cross',
            address: 'London N1C 4AP',
            lat: 51.5308,
            lng: -0.1238,
          ),
      driver: driver,
    );

const _driver = DriverInfo(
  name: 'James K.',
  rating: 4.9,
  vehicle: 'Silver Toyota Prius · Economy',
  plate: 'LB12 KXR',
);

void main() {
  test('carries the details that identify the car', () {
    final msg = buildTripShareMessage(_trip(driver: _driver));

    // Registration is the one field that lets someone identify the vehicle.
    expect(msg, contains('LB12 KXR'));
    expect(msg, contains('James K.'));
    expect(msg, contains('Silver Toyota Prius · Economy'));
    expect(msg, contains('Tower Bridge'));
    expect(msg, contains('Kings Cross'));
  });

  test('still sends something useful before a driver is assigned', () {
    final msg = buildTripShareMessage(_trip());

    expect(msg, contains('Kings Cross'));
    expect(msg, isNot(contains('Driver:')));
    expect(msg, isNot(contains('Registration:')));
  });

  test('includes a maps link only when a position is known', () {
    final without = buildTripShareMessage(_trip(driver: _driver));
    expect(without, isNot(contains('google.com/maps')));

    final with_ = buildTripShareMessage(
      _trip(driver: _driver),
      driverPosition: const DriverLocation(lat: 51.5074, lng: -0.1278),
    );
    expect(with_, contains('query=51.50740,-0.12780'));
  });

  test('does not claim to be a live link', () {
    final msg = buildTripShareMessage(
      _trip(driver: _driver),
      driverPosition: const DriverLocation(lat: 51.5074, lng: -0.1278),
    );
    // The wording must stay past-tense: the link is a snapshot, and a rider
    // relying on it as live tracking is the dangerous misreading.
    expect(msg, contains('Where we were when I sent this'));
    expect(msg.toLowerCase(), isNot(contains('live location')));
    expect(msg.toLowerCase(), isNot(contains('track me')));
  });

  test('does not repeat a place whose label and address are the same', () {
    final msg = buildTripShareMessage(_trip(
      dropoff: const Place(
        label: 'London N1C 4AP',
        address: 'London N1C 4AP',
        lat: 51.5308,
        lng: -0.1238,
      ),
    ));

    expect(msg, contains('To: London N1C 4AP'));
    expect(msg, isNot(contains('London N1C 4AP — London N1C 4AP')));
  });

  test('drops an empty label or address rather than leaving a dangling dash', () {
    final msg = buildTripShareMessage(_trip(
      pickup: const Place(label: '', address: 'London SE1 2UP', lat: 0, lng: 0),
    ));

    expect(msg, contains('From: London SE1 2UP'));
    expect(msg, isNot(contains('From:  — ')));
  });
}
