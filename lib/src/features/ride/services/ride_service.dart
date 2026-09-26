import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_message.dart';
import '../models/driver_location.dart';
import '../models/place.dart';
import '../models/trip.dart';

/// Contract the ride flow programs against, implemented by [DioRideRepository]
/// against the live API. A canned [MockRideRepository] used to sit alongside it
/// for the pre-API prototype; it was removed once the trips endpoints shipped,
/// so there is no path left that can serve invented trips.
abstract class RideRepository {
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

  /// The caller's currently active trip (requested, assigned, arrived, or in-progress)
  /// with full driver details, vehicle info, and meet-up PIN, or null if none.
  Future<Trip?> getActiveTrip();

  /// The assigned driver's last known position, or null if there's nothing to
  /// show yet. Seeds the tracking map before the realtime pushes take over.
  Future<DriverLocation?> driverLocation(String tripId);

  Future<Trip> cancelTrip(String id, {String? reason});

  /// Give a still-open request another search window and put it back in front
  /// of drivers — the customer's "keep searching" when nobody has taken it yet.
  /// Throws if the search has already ended or the extensions are used up.
  Future<Trip> extendTrip(String id);

  Future<List<Trip>> tripHistory();

  Future<void> submitRating(String tripId, {required int score, String? comment});

  Future<List<ChatMessage>> getMessages(String tripId);

  Future<ChatMessage> sendMessage(String tripId, {required String content});
}

// ─────────────────────────────────────────────────────────────────────────────
// The live implementation, against the API's `/api/v1/trips` endpoints.
// Prices are not fetched here: the app prices on-device from the fare chart
// (`rideQuoteProvider`) and the API re-prices authoritatively at booking.
// Place search goes straight to Google (`MapsService.autocomplete`).
// ─────────────────────────────────────────────────────────────────────────────
class DioRideRepository implements RideRepository {
  DioRideRepository(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/trips';

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
  Future<Trip?> getActiveTrip() => apiCall(() async {
        try {
          final res = await _dio.get<Map<String, dynamic>>('$_base/active');
          final data = res.data;
          if (data == null || data.isEmpty) return null;
          return Trip.fromJson(data);
        } on DioException catch (e) {
          if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
            return null;
          }
          rethrow;
        }
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
  Future<Trip> extendTrip(String id) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>('$_base/$id/extend');
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

/// The signed-in customer's past trips (`GET /trips`), most recent first — backs
/// the Activity/history screen.
final tripHistoryProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final trips = await ref.watch(rideRepositoryProvider).tripHistory();
  trips.sort((a, b) =>
      (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return trips;
});
