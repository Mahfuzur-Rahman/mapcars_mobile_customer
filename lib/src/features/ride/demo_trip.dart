import 'models/driver_info.dart';
import 'models/place.dart';
import 'models/trip.dart';
import 'models/trip_status.dart';

/// A fake trip used only to preview the searching/in-progress dev-walkthrough
/// screens with a real map instead of the static hand-painted fallback. Never
/// used in the live booking flow — production screens always get a real
/// [Trip] via [RideFlowState.activeTrip]. Coordinates match the same demo
/// route already used as fallback text across these screens (Canary Wharf →
/// Tower Bridge), and the driver app's own `demoTrip`.
final demoTrip = Trip(
  id: 'demo-trip',
  status: TripStatus.inProgress,
  pickup: const Place(
    label: '40 Canary Wharf, London E14',
    address: '40 Canary Wharf, London E14',
    lat: 51.5054,
    lng: -0.0235,
  ),
  dropoff: const Place(
    label: 'Tower Bridge, SE1',
    address: 'Tower Bridge, SE1',
    lat: 51.5055,
    lng: -0.0754,
  ),
  driver: const DriverInfo(
    name: 'James K.',
    rating: 4.9,
    vehicle: 'Silver Toyota Prius · Economy',
    plate: 'LB12 KXR',
  ),
  farePence: 801,
  pin: '1234',
  createdAt: DateTime.utc(2026, 1, 1),
);
