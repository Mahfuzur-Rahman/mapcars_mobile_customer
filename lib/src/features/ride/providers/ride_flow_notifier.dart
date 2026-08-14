import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/realtime/realtime_service.dart';
import '../models/chat_message.dart';
import '../models/driver_location.dart';
import '../models/place.dart';
import '../models/ride_quote.dart';
import '../models/trip.dart';
import '../models/trip_status.dart';
import '../services/fare_calculator.dart';
import '../services/ride_service.dart';
import 'fare_chart_provider.dart';
import '../../../core/network/friendly_error.dart';

/// In-progress booking, carried across the set-route → choose-ride → confirm →
/// tracking screens. Immutable; mutated only through [RideFlowNotifier].
class RideFlowState {
  const RideFlowState({
    this.pickup,
    this.dropoff,
    this.distanceMiles,
    this.durationMinutes,
    this.selectedOptionId,
    this.activeTrip,
    this.driverLocation,
    this.chatMessages = const [],
    this.isLoading = false,
    this.error,
  });

  final Place? pickup;
  final Place? dropoff;

  /// Route metrics from the directions preview — the inputs the fare chart is
  /// priced against. Null until a route has been previewed.
  final double? distanceMiles;
  final int? durationMinutes;

  final String? selectedOptionId;
  final Trip? activeTrip;

  /// Where the assigned driver is right now — seeded from
  /// `GET /trips/{id}/driver-location` and then kept current by the
  /// `driverLocation` realtime push. Null until a driver is assigned and
  /// reporting.
  final DriverLocation? driverLocation;

  /// Chat messages for the active trip — seeded from GET on mount,
  /// appended by messageReceived pushes and local sends.
  final List<ChatMessage> chatMessages;

  final bool isLoading;
  final String? error;

  bool get hasRoute => pickup != null && dropoff != null;

  RideFlowState copyWith({
    Place? pickup,
    Place? dropoff,
    double? distanceMiles,
    int? durationMinutes,
    String? selectedOptionId,
    Trip? activeTrip,
    DriverLocation? driverLocation,
    List<ChatMessage>? chatMessages,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearTrip = false,
  }) =>
      RideFlowState(
        pickup: pickup ?? this.pickup,
        dropoff: dropoff ?? this.dropoff,
        distanceMiles: distanceMiles ?? this.distanceMiles,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        selectedOptionId: selectedOptionId ?? this.selectedOptionId,
        activeTrip: clearTrip ? null : (activeTrip ?? this.activeTrip),
        // Clearing the trip clears the car with it — a stale marker left on the
        // map after the ride ends is worse than no marker.
        driverLocation:
            clearTrip ? null : (driverLocation ?? this.driverLocation),
        chatMessages: clearTrip ? const [] : (chatMessages ?? this.chatMessages),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class RideFlowNotifier extends StateNotifier<RideFlowState> {
  RideFlowNotifier(this._repo, this._ref) : super(const RideFlowState());

  final RideRepository _repo;
  final Ref _ref;
  final RealtimeService _rt = RealtimeService();

  void setRoute({
    required Place pickup,
    required Place dropoff,
    double? distanceMiles,
    int? durationMinutes,
  }) {
    state = state.copyWith(
      pickup: pickup,
      dropoff: dropoff,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      clearError: true,
    );
  }

  void selectOption(String optionId) {
    state = state.copyWith(selectedOptionId: optionId);
  }

  /// Books the trip with the currently selected option. Returns the trip, or
  /// null on failure (with [RideFlowState.error] set).
  Future<Trip?> confirmTrip({
    String? promoCode,
    String? paymentMethod,
    String? paymentMethodId,
    double tipAmount = 0,
  }) async {
    final pickup = state.pickup, dropoff = state.dropoff;
    final optionId = state.selectedOptionId;
    if (pickup == null || dropoff == null || optionId == null) return null;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trip = await _repo.requestTrip(
        pickup: pickup,
        dropoff: dropoff,
        rideOptionId: optionId,
        distanceMiles: state.distanceMiles ?? 0,
        durationMinutes: state.durationMinutes ?? 0,
        promoCode: promoCode,
        paymentMethod: paymentMethod,
        paymentMethodId: paymentMethodId,
        tipAmount: tipAmount,
      );
      state = state.copyWith(isLoading: false, activeTrip: trip);
      unawaited(_startRealtime(trip.id));
      return trip;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return null;
    }
  }

  /// Joins the trip's SignalR group so `tripUpdated` pushes (driver assigned,
  /// arrived, started, completed, cancelled) update [RideFlowState.activeTrip]
  /// live — this is what lets the searching/tracking screens react instead of
  /// polling — and `driverLocation` pushes move the car on the map.
  /// Best-effort: a failed connect just falls back to [refreshActiveTrip]
  /// polling wherever a screen already calls it.
  Future<void> _startRealtime(String tripId) async {
    final token = _ref.read(authTokenProvider);
    if (token == null) return;
    await _rt.connect(token, {
      'tripUpdated': _onTripUpdated,
      'driverLocation': _onDriverLocation,
      'messageReceived': _onMessageReceived,
    });
    await _rt.invoke('JoinTrip', args: [tripId]);
  }

  /// Attaches to a trip that's already running — the app was reopened mid-ride,
  /// so there's no [confirmTrip] call to have started realtime. Seeds the
  /// driver's position over REST (every push so far has been missed) and then
  /// joins the group for the rest.
  Future<void> resumeTrip(Trip trip) async {
    state = state.copyWith(activeTrip: trip, clearError: true);
    await _startRealtime(trip.id);
    await refreshDriverLocation();
  }

  /// Looks for a trip still in flight and re-attaches to it. Called on app
  /// start: without this, a rider whose app was killed mid-ride (which Android
  /// does freely to a backgrounded app) comes back to a "Where to?" home screen
  /// while their driver is en route, with no way back to the tracking map.
  ///
  /// Returns the resumed trip, or null if there's nothing in flight.
  Future<Trip?> resumeActiveTrip() async {
    if (state.activeTrip != null) return state.activeTrip;
    try {
      final trips = await _repo.tripHistory();
      final live = trips.where((t) =>
          t.status == TripStatus.requested || t.status.isActive);
      if (live.isEmpty) return null;

      // Most recently booked wins if the backend ever hands back more than one.
      final trip = live.reduce((a, b) =>
          (a.createdAt ?? DateTime(0)).isAfter(b.createdAt ?? DateTime(0))
              ? a
              : b);
      await resumeTrip(trip);
      return trip;
    } catch (_) {
      // Offline or the call failed — home is a safe place to land.
      return null;
    }
  }

  /// One-shot fetch of the driver's last known position. Called when a tracking
  /// screen mounts, so the map has a car on it immediately instead of waiting
  /// up to 5s for the next push — or forever, if the driver's app has stalled.
  Future<void> refreshDriverLocation() async {
    final id = state.activeTrip?.id;
    if (id == null) return;
    try {
      final position = await _repo.driverLocation(id);
      if (position == null || !mounted) return;
      state = state.copyWith(driverLocation: position);
    } catch (_) {
      // Nothing to show is the same outcome as before the call — the realtime
      // push is the primary path and will correct this shortly.
    }
  }

  void _onDriverLocation(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      final position =
          DriverLocation.fromJson(Map<String, dynamic>.from(raw));
      if (mounted) state = state.copyWith(driverLocation: position);
    } catch (e) {
      if (kDebugMode) debugPrint('[ride] bad driverLocation payload: $e');
    }
  }

  void _onTripUpdated(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      final trip = Trip.fromJson(Map<String, dynamic>.from(raw));
      if (trip.id != state.activeTrip?.id) return;
      if (mounted) state = state.copyWith(activeTrip: trip);
    } catch (e) {
      if (kDebugMode) debugPrint('[ride] bad tripUpdated payload: $e');
    }
  }

  void _onMessageReceived(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is! Map) return;
    try {
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(raw));
      if (msg.tripId != state.activeTrip?.id) return;
      // Deduplicate: the sender's own echo is already appended optimistically
      // by sendMessage — skip it if we see it again from the push.
      final already = state.chatMessages.any((m) => m.id == msg.id);
      if (!already && mounted) {
        state = state.copyWith(
            chatMessages: [...state.chatMessages, msg]);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ride] bad messageReceived payload: $e');
    }
  }

  Future<void> _stopRealtime() => _rt.disconnect();

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

  Future<void> cancelActiveTrip({String? reason}) async {
    final id = state.activeTrip?.id;
    if (id == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trip = await _repo.cancelTrip(id, reason: reason);
      state = state.copyWith(isLoading: false, activeTrip: trip);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
    }
  }

  /// Submits the rider's 1-5 star rating (+ optional comment) for [tripId].
  /// Returns true on success, false on failure (with [RideFlowState.error] set).
  Future<bool> submitRating(String tripId, {required int score, String? comment}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.submitRating(tripId, score: score, comment: comment);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return false;
    }
  }

  /// Dev-only: seeds a demo trip so the "Screens" walkthrough's searching/
  /// in-progress previews render the real map instead of static art. A no-op
  /// whenever a real trip is already active, so it can never clobber a live
  /// ride the rider is actually on.
  void previewDemoTrip(Trip trip) {
    if (state.activeTrip != null) return;
    state = state.copyWith(activeTrip: trip);
  }

  void reset() {
    unawaited(_stopRealtime());
    state = const RideFlowState();
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Fetches the full message history for the active trip (called on chat
  /// screen mount). Replaces whatever is in state.
  Future<void> fetchMessages() async {
    final id = state.activeTrip?.id;
    if (id == null) return;
    try {
      final messages = await _repo.getMessages(id);
      if (mounted) state = state.copyWith(chatMessages: messages);
    } catch (e) {
      if (kDebugMode) debugPrint('[ride] fetchMessages failed: $e');
    }
  }

  /// Sends a message and appends the server's response (with its real ID)
  /// to state. The realtime push will also arrive, but [_onMessageReceived]
  /// deduplicates by ID so there's no double.
  Future<void> sendMessage(String content) async {
    final id = state.activeTrip?.id;
    if (id == null) return;
    try {
      final msg = await _repo.sendMessage(id, content: content);
      if (mounted) {
        state = state.copyWith(
            chatMessages: [...state.chatMessages, msg]);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ride] sendMessage failed: $e');
    }
  }

  @override
  void dispose() {
    _rt.disconnect();
    super.dispose();
  }
}

final rideFlowProvider =
    StateNotifierProvider<RideFlowNotifier, RideFlowState>(
  (ref) => RideFlowNotifier(ref.watch(rideRepositoryProvider), ref),
);

/// Prices the current route **on-device** from the API's fare chart — no
/// per-route round-trip, so tier prices appear instantly. The chart is fetched
/// once and cached ([fareChartProvider]); this recomputes locally whenever the
/// route changes. The API re-prices authoritatively at booking from the same
/// chart, so the shown price matches the charged price.
///
/// Falls back to a default route so the choose-ride screen still renders when
/// navigated to directly (e.g. via the dev stepper).
final rideQuoteProvider = FutureProvider.autoDispose<RideQuote>((ref) async {
  final flow = ref.watch(rideFlowProvider);
  final chart = await ref.watch(fareChartProvider.future);

  const fallbackPickup =
      Place(label: 'Current location', address: '', lat: 51.5054, lng: -0.0235);
  const fallbackDropoff =
      Place(label: 'Destination', address: '', lat: 51.5055, lng: -0.0754);

  final pickup = flow.pickup ?? fallbackPickup;
  final dropoff = flow.dropoff ?? fallbackDropoff;

  // Use the previewed route metrics when present; otherwise estimate from the
  // straight-line distance (× a typical road factor) so a direct-navigation
  // still shows a sensible price.
  final straightMiles = FareCalculator.haversineMeters(
        pickup.lat, pickup.lng, dropoff.lat, dropoff.lng,
      ) /
      1609.344;
  final miles = flow.distanceMiles ?? straightMiles * 1.35;
  final minutes =
      (flow.durationMinutes ?? (miles / 18.0 * 60.0).round()).toDouble();

  final options = FareCalculator.options(
    chart: chart,
    miles: miles,
    minutes: minutes,
    pickupLat: pickup.lat,
    pickupLng: pickup.lng,
    dropoffLat: dropoff.lat,
    dropoffLng: dropoff.lng,
  );

  return RideQuote(
    distanceMiles: double.parse(miles.toStringAsFixed(1)),
    etaMinutes: minutes.round(),
    options: options,
  );
});
