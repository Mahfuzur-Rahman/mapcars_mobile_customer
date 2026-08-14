import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/saved_place.dart';

/// Talks to the rider "saved places" endpoints (Home/Work/custom addresses).
/// Mirrors `Mapcars.Api/Controllers/SavedPlacesController.cs`
/// (`/api/v1/saved-places`) — rider-only.
class SavedPlacesService {
  SavedPlacesService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/saved-places';

  Future<List<SavedPlace>> list() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>(_base);
        return (res.data ?? [])
            .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<SavedPlace> create({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          _base,
          data: {'label': label, 'address': address, 'lat': lat, 'lng': lng},
        );
        return SavedPlace.fromJson(res.data!);
      });

  Future<SavedPlace> update(
    String id, {
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) =>
      apiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '$_base/$id',
          data: {'label': label, 'address': address, 'lat': lat, 'lng': lng},
        );
        return SavedPlace.fromJson(res.data!);
      });

  Future<void> delete(String id) => apiCall(() async {
        await _dio.delete<void>('$_base/$id');
      });
}

final savedPlacesServiceProvider = Provider<SavedPlacesService>(
  (ref) => SavedPlacesService(ref.watch(dioProvider)),
);
