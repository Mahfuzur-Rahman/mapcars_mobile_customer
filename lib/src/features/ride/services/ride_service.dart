import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/driver_info.dart';
import '../models/place.dart';
import '../models/ride_option.dart';
import '../models/ride_quote.dart';
import '../models/trip.dart';
import '../models/trip_status.dart';

/// Contract the ride flow programs against. Two implementations exist:
/// [DioRideRepository] (the real, API-backed one) and [MockRideRepository]
/// (returns canned data so the app runs before the trips endpoints ship).
abstract class RideRepository {
  Future<List<Place>> searchPlaces(String query);

  Future<RideQuote> quote({required Place pickup, required Place dropoff});

  Future<Trip> requestTrip({
    required Place pickup,
    required Place dropoff,
    required String rideOptionId,
    String? promoCode,
    String? paymentMethodId,
  });

  Future<Trip> getTrip(String id);

  Future<Trip> cancelTrip(String id);

  Future<List<Trip>> tripHistory();
}

// ─────────────────────────────────────────────────────────────────────────────
// Real implementation — PROPOSED contract. These endpoints do not exist on the
// API yet; align them with the controller once the trips slice is built, then
// flip [rideRepositoryProvider] from the mock to this. The shapes deliberately
// mirror the backend `Trip` entity and `TripStatus` enum.
// ─────────────────────────────────────────────────────────────────────────────
class DioRideRepository implements RideRepository {
  DioRideRepository(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/trips'; // PROPOSED

  @override
  Future<List<Place>> searchPlaces(String query) => apiCall(() async {
        final res = await _dio.get<List<dynamic>>(
          '/api/v1/places/search',
          queryParameters: {'q': query},
        );
        return (res.data ?? [])
            .map((e) => Place.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      });

  @override
  Future<RideQuote> quote({required Place pickup, required Place dropoff}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/quote',
          data: {'pickup': pickup.toJson(), 'dropoff': dropoff.toJson()},
        );
        return RideQuote.fromJson(res.data!);
      });

  @override
  Future<Trip> requestTrip({
    required Place pickup,
    required Place dropoff,
    required String rideOptionId,
    String? promoCode,
    String? paymentMethodId,
  }) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          _base,
          data: {
            'pickup': pickup.toJson(),
            'dropoff': dropoff.toJson(),
            'rideOptionId': rideOptionId,
            if (promoCode != null) 'promoCode': promoCode,
            if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
          },
        );
        return Trip.fromJson(res.data!);
      });

  @override
  Future<Trip> getTrip(String id) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/$id');
        return Trip.fromJson(res.data!);
      });

  @override
  Future<Trip> cancelTrip(String id) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>('$_base/$id/cancel');
        return Trip.fromJson(res.data!);
      });

  @override
  Future<List<Trip>> tripHistory() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>(_base);
        return (res.data ?? [])
            .map((e) => Trip.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      });
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock implementation — mirrors the data the screens currently hard-code, so
// the prototype flow keeps working end-to-end until the API lands.
// ─────────────────────────────────────────────────────────────────────────────
class MockRideRepository implements RideRepository {
  static const _delay = Duration(milliseconds: 350);

  static const _places = [
    Place(label: 'Tower Bridge', address: 'London SE1 2UP', lat: 51.5055, lng: -0.0754),
    Place(label: 'Borough Market', address: '8 Southwark St, SE1', lat: 51.5055, lng: -0.0909),
    Place(label: 'Liverpool St Station', address: 'London EC2M 7PY', lat: 51.5178, lng: -0.0823),
  ];

  static const _defaultPickup =
      Place(label: '40 Canary Wharf', address: 'Canary Wharf, E14', lat: 51.5054, lng: -0.0235);

  @override
  Future<List<Place>> searchPlaces(String query) async {
    await Future<void>.delayed(_delay);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _places;
    return _places
        .where((p) =>
            p.label.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Future<RideQuote> quote({required Place pickup, required Place dropoff}) async {
    await Future<void>.delayed(_delay);
    return const RideQuote(
      distanceMiles: 4.3,
      etaMinutes: 12,
      options: [
        RideOption(id: 'economy', tier: 'economy', name: 'Economy', etaMinutes: 3, pricePence: 890, description: 'Everyday rides', icon: 'car'),
        RideOption(id: 'comfort', tier: 'comfort', name: 'Comfort', etaMinutes: 5, pricePence: 1240, description: 'Newer cars, more room', icon: 'car'),
        RideOption(id: 'xl', tier: 'xl', name: 'XL', etaMinutes: 6, pricePence: 1650, description: 'Up to 6 seats', icon: 'car'),
        RideOption(id: 'premium', tier: 'premium', name: 'Premium', etaMinutes: 4, pricePence: 2100, description: 'Top-rated drivers', icon: 'bolt'),
      ],
    );
  }

  @override
  Future<Trip> requestTrip({
    required Place pickup,
    required Place dropoff,
    required String rideOptionId,
    String? promoCode,
    String? paymentMethodId,
  }) async {
    await Future<void>.delayed(_delay);
    return Trip(
      id: 'mock-trip',
      status: TripStatus.driverAssigned,
      pickup: pickup,
      dropoff: dropoff,
      pin: '4821',
      driver: const DriverInfo(
        name: 'James K.',
        rating: 4.9,
        vehicle: 'Silver Toyota Prius · Economy',
        plate: 'LB12 KXR',
      ),
    );
  }

  @override
  Future<Trip> getTrip(String id) async {
    await Future<void>.delayed(_delay);
    return Trip(
      id: id,
      status: TripStatus.inProgress,
      pickup: _defaultPickup,
      dropoff: _places.first,
      pin: '4821',
      driver: const DriverInfo(
        name: 'James K.',
        rating: 4.9,
        vehicle: 'Silver Toyota Prius · Economy',
        plate: 'LB12 KXR',
      ),
    );
  }

  @override
  Future<Trip> cancelTrip(String id) async {
    await Future<void>.delayed(_delay);
    return Trip(
      id: id,
      status: TripStatus.cancelledByRider,
      pickup: _defaultPickup,
      dropoff: _places.first,
    );
  }

  @override
  Future<List<Trip>> tripHistory() async {
    await Future<void>.delayed(_delay);
    return [
      Trip(
        id: 'mock-1',
        status: TripStatus.completed,
        pickup: _defaultPickup,
        dropoff: _places.first,
        farePence: 801,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}

/// Swap to `DioRideRepository(ref.watch(dioProvider))` once the trips endpoints
/// ship. Everything above this line (models, providers, screens) stays the same.
final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => MockRideRepository(),
);
