import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/saved_places_service.dart';

/// The signed-in rider's saved places. A plain autoDispose FutureProvider —
/// the screen calls `ref.invalidate(savedPlacesProvider)` after a
/// create/update/delete to refresh the list (same pattern as
/// `ride/providers/ride_flow_notifier.dart`'s `rideQuoteProvider`).
final savedPlacesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(savedPlacesServiceProvider).list();
});
