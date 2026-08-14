import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/fare_chart.dart';

/// Fetches and caches the pricing config from the API (`GET /api/v1/fare-chart`).
///
/// Cached for the app session (a plain [FutureProvider], not autoDispose) so the
/// quote screen prices instantly with no per-route round-trip. Call
/// `ref.invalidate(fareChartProvider)` to force a refresh (e.g. on a pricing
/// error retry, or after a long background). The endpoint is public — no auth
/// needed to read prices.
final fareChartProvider = FutureProvider<FareChart>((ref) async {
  final dio = ref.watch(dioProvider);
  return apiCall(() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/fare-chart');
    return FareChart.fromJson(res.data!);
  });
});
