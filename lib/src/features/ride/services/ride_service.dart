import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_message.dart';
import '../models/driver_location.dart';
import '../models/place.dart';
import '../models/ride_quote.dart';
import '../models/trip.dart';

/// Contract the ride flow programs against, implemented by [DioRideRepository]
/// against the live API. A canned [MockRideRepository] used to sit alongside it
/// for the pre-API prototype; it was removed once the trips endpoints shipped,
/// so there is no path left that can serve invented trips.
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

/// Real, API-backed booking.
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
