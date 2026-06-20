import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place.dart';
import '../models/ride_quote.dart';
import '../models/trip.dart';
import '../services/ride_service.dart';

/// In-progress booking, carried across the set-route → choose-ride → confirm →
/// tracking screens. Immutable; mutated only through [RideFlowNotifier].
class RideFlowState {
  const RideFlowState({
    this.pickup,
    this.dropoff,
    this.selectedOptionId,
    this.activeTrip,
    this.isLoading = false,
    this.error,
  });

  final Place? pickup;
  final Place? dropoff;
  final String? selectedOptionId;
  final Trip? activeTrip;
  final bool isLoading;
  final String? error;

  bool get hasRoute => pickup != null && dropoff != null;

  RideFlowState copyWith({
    Place? pickup,
    Place? dropoff,
    String? selectedOptionId,
    Trip? activeTrip,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearTrip = false,
  }) =>
      RideFlowState(
        pickup: pickup ?? this.pickup,
        dropoff: dropoff ?? this.dropoff,
        selectedOptionId: selectedOptionId ?? this.selectedOptionId,
        activeTrip: clearTrip ? null : (activeTrip ?? this.activeTrip),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class RideFlowNotifier extends StateNotifier<RideFlowState> {
  RideFlowNotifier(this._repo) : super(const RideFlowState());

  final RideRepository _repo;

  void setRoute({required Place pickup, required Place dropoff}) {
    state = state.copyWith(pickup: pickup, dropoff: dropoff, clearError: true);
  }

  void selectOption(String optionId) {
    state = state.copyWith(selectedOptionId: optionId);
  }

  /// Books the trip with the currently selected option. Returns the trip, or
  /// null on failure (with [RideFlowState.error] set).
  Future<Trip?> confirmTrip({String? promoCode, String? paymentMethodId}) async {
    final pickup = state.pickup, dropoff = state.dropoff;
    final optionId = state.selectedOptionId;
    if (pickup == null || dropoff == null || optionId == null) return null;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trip = await _repo.requestTrip(
        pickup: pickup,
        dropoff: dropoff,
        rideOptionId: optionId,
        promoCode: promoCode,
        paymentMethodId: paymentMethodId,
      );
      state = state.copyWith(isLoading: false, activeTrip: trip);
      return trip;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> refreshActiveTrip() async {
    final id = state.activeTrip?.id;
    if (id == null) return;
    try {
      final trip = await _repo.getTrip(id);
      state = state.copyWith(activeTrip: trip);
    } catch (_) {
      // Keep the last known trip on a transient poll failure.
    }
  }

  Future<void> cancelActiveTrip() async {
    final id = state.activeTrip?.id;
    if (id == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trip = await _repo.cancelTrip(id);
      state = state.copyWith(isLoading: false, activeTrip: trip);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const RideFlowState();
}

final rideFlowProvider =
    StateNotifierProvider<RideFlowNotifier, RideFlowState>(
  (ref) => RideFlowNotifier(ref.watch(rideRepositoryProvider)),
);

/// Prices the current route. Falls back to a default route so the choose-ride
/// screen still renders when navigated to directly (e.g. via the dev stepper).
final rideQuoteProvider = FutureProvider.autoDispose<RideQuote>((ref) {
  final flow = ref.watch(rideFlowProvider);
  final repo = ref.watch(rideRepositoryProvider);
  final pickup = flow.pickup ??
      const Place(label: 'Current location', address: '', lat: 51.5054, lng: -0.0235);
  final dropoff = flow.dropoff ??
      const Place(label: 'Destination', address: '', lat: 51.5055, lng: -0.0754);
  return repo.quote(pickup: pickup, dropoff: dropoff);
});
