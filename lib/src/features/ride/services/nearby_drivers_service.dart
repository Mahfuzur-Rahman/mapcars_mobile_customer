import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// One online driver near a point, as returned by `GET /api/v1/drivers/nearby`.
class NearbyDriver {
  const NearbyDriver({
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.heading,
  });

  final String driverId;
  final double lat;
  final double lng;
  final double distanceMeters;

  /// Compass heading in degrees (0 = north, clockwise), when the driver's
  /// device supplied one — null if unknown.
  final double? heading;

  factory NearbyDriver.fromJson(Map<String, dynamic> j) => NearbyDriver(
        driverId: j['driverId'].toString(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0,
        heading: (j['heading'] as num?)?.toDouble(),
      );
}

/// Reads nearby online drivers from the API (Redis GEO). Rider-scoped — the
/// Dio interceptor attaches the rider token; an unauthenticated call returns
/// 401 (handled by the caller as "no cars to show").
class NearbyDriversService {
  NearbyDriversService(this._dio);
  final Dio _dio;

  Future<List<NearbyDriver>> nearby(
    double lat,
    double lng, {
    double radiusMeters = 5000,
    int limit = 20,
  }) =>
      apiCall(() async {
        final res = await _dio.get<List<dynamic>>(
          '/api/v1/drivers/nearby',
          queryParameters: {
            'lat': lat,
            'lng': lng,
            'radiusMeters': radiusMeters,
            'limit': limit,
          },
        );
        return (res.data ?? const [])
            .map((e) => NearbyDriver.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      });
}

final nearbyDriversServiceProvider = Provider<NearbyDriversService>(
  (ref) => NearbyDriversService(ref.watch(dioProvider)),
);
