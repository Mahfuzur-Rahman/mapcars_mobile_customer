import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_message.dart';
import '../models/driver_info.dart';
import '../models/driver_location.dart';
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
    required double distanceMiles,
    required int durationMinutes,
    String? promoCode,
    String? paymentMethod,
    String? paymentMethodId,
    double tipAmount,
  });

  Future<Trip> getTrip(String id);

  /// The assigned driver's last known position, or null if there's nothing to
  /// show yet. Seeds the tracking map before the realtime pushes take over.
  Future<DriverLocation?> driverLocation(String tripId);

  Future<Trip> cancelTrip(String id, {String? reason});

  Future<List<Trip>> tripHistory();

  Future<void> submitRating(String tripId, {required int score, String? comment});

  Future<List<ChatMessage>> getMessages(String tripId);

  Future<ChatMessage> sendMessage(String tripId, {required String content});
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
        // Server-side quote (secondary path — the app normally prices locally
        // from the fare chart via rideQuoteProvider). Distance 0 lets the API
        // estimate from the straight-line distance.
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/quote',
          data: {
            'pickupLat': pickup.lat,
            'pickupLng': pickup.lng,
            'dropoffLat': dropoff.lat,
            'dropoffLng': dropoff.lng,
            'distanceMiles': 0,
            'durationMinutes': 0,
          },
        );
        return RideQuote.fromJson(res.data!);
      });

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
  }) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          _base,
          data: {
            'pickupAddress':
                pickup.address.isNotEmpty ? pickup.address : pickup.label,
            'pickupLat': pickup.lat,
            'pickupLng': pickup.lng,
            'dropoffAddress':
                dropoff.address.isNotEmpty ? dropoff.address : dropoff.label,
            'dropoffLat': dropoff.lat,
            'dropoffLng': dropoff.lng,
            'rideOptionId': rideOptionId,
            'distanceMiles': distanceMiles,
            'durationMinutes': durationMinutes,
            if (promoCode != null) 'promoCode': promoCode,
            if (paymentMethod != null) 'paymentMethod': paymentMethod,
            if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
            'tipAmount': tipAmount,
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
  Future<DriverLocation?> driverLocation(String tripId) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '$_base/$tripId/driver-location',
        );
        // 204 when there's nothing to report — no driver assigned yet, the trip
        // is over, or the driver isn't currently reporting a position.
        final data = res.data;
        if (data == null || data.isEmpty) return null;
        return DriverLocation.fromJson(data);
      });

  @override
  Future<Trip> cancelTrip(String id, {String? reason}) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/$id/cancel',
          data: {
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          },
        );
        return Trip.fromJson(res.data!);
      });

  @override
  Future<List<Trip>> tripHistory() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>(_base);
        return (res.data ?? [])
            .map((e) => Trip.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      });

  @override
  Future<void> submitRating(String tripId, {required int score, String? comment}) =>
      apiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '$_base/$tripId/ratings',
          data: {
            'score': score,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          },
        );
      });

  @override
  Future<List<ChatMessage>> getMessages(String tripId) =>
      apiCall(() async {
        final res = await _dio.get<List<dynamic>>('$_base/$tripId/messages');
        return (res.data ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<ChatMessage> sendMessage(String tripId, {required String content}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/$tripId/messages',
          data: {'content': content},
        );
        return ChatMessage.fromJson(res.data!);
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
    required double distanceMiles,
    required int durationMinutes,
    String? promoCode,
    String? paymentMethod,
    String? paymentMethodId,
    double tipAmount = 0,
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
  Future<DriverLocation?> driverLocation(String tripId) async {
    await Future<void>.delayed(_delay);
    // A fixed point just north-east of `_defaultPickup` — enough for the
    // tracking screen to render a car without a live driver.
    return const DriverLocation(lat: 51.5094, lng: -0.0205, heading: 210);
  }

  @override
  Future<Trip> cancelTrip(String id, {String? reason}) async {
    await Future<void>.delayed(_delay);
    // Mock has no backing store — the reason is accepted (mirroring the real
    // API contract) but there's nothing to persist it against.
    return Trip(
      id: id,
      status: TripStatus.cancelledByRider,
      pickup: _defaultPickup,
      dropoff: _places.first,
    );
  }

  @override
  Future<void> submitRating(String tripId, {required int score, String? comment}) async {
    await Future<void>.delayed(_delay);
  }

  @override
  Future<List<ChatMessage>> getMessages(String tripId) async {
    await Future<void>.delayed(_delay);
    return [];
  }

  @override
  Future<ChatMessage> sendMessage(String tripId, {required String content}) async {
    await Future<void>.delayed(_delay);
    return ChatMessage(
      id: 'mock-msg-${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      senderType: 'rider',
      senderId: 'mock-rider',
      content: content,
      sentAtUtc: DateTime.now().toUtc(),
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

/// Real, API-backed booking. (Was `MockRideRepository` during the prototype;
/// flipped now that the trips endpoints are live and dispatch is wired.)
final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => DioRideRepository(ref.watch(dioProvider)),
);

/// The signed-in rider's past trips (`GET /trips`), most recent first — backs
/// the Activity/history screen.
final tripHistoryProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final trips = await ref.watch(rideRepositoryProvider).tripHistory();
  trips.sort((a, b) =>
      (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return trips;
});
