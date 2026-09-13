import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/payment_settings.dart';

/// Fetches and caches the platform's payment settings
/// (`GET /api/v1/payment-settings`).
///
/// Session-cached as a plain [FutureProvider], deliberately mirroring
/// [fareChartProvider]: the booking sheet needs it the moment it opens, and a
/// round-trip there would be visible. `ref.invalidate` forces a refresh. The
/// endpoint is public, so this works before sign-in — which matters, because the
/// splash warms it while the customer may still be signed out.
final paymentSettingsProvider = FutureProvider<PaymentSettings>((ref) async {
  final dio = ref.watch(dioProvider);
  return apiCall(() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/payment-settings');
    return PaymentSettings.fromJson(res.data!);
  });
});

/// The settings, or the cash-only fallback while loading or on error.
///
/// The booking sheet should never block on this: a customer who opened the app
/// to get a car should not be looking at a spinner because a config call is
/// slow. Falling back to cash keeps the flow usable, and the server is still the
/// authority on whether the chosen method is allowed.
final paymentSettingsOrFallbackProvider = Provider<PaymentSettings>((ref) {
  return ref.watch(paymentSettingsProvider).maybeWhen(
        data: (s) => s,
        orElse: () => PaymentSettings.fallback,
      );
});
