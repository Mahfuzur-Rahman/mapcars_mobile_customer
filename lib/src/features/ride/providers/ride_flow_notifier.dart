import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/notifications/trip_alerts.dart';
import '../../../core/realtime/realtime_service.dart';
import '../models/chat_message.dart';
import '../models/directions_result.dart';
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
    this.route,
    this.distanceMiles,
    this.durationMinutes,
    this.selectedOptionId,
    this.activeTrip,
    this.driverLocation,
    this.chatMessages = const [],
    this.realtimeConnected = false,
    this.isLoading = false,
    this.error,
  });

  final Place? pickup;
  final Place? dropoff;

  /// The driving route as fetched once on the preview screen. Kept here so the
  /// choose-ride / confirm / searching maps can draw the **real** line without
  /// each paying for its own Directions call (they used to sit on decorative
  /// hand-painted map art instead).
  final DirectionsResult? route;

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

  /// Whether the SignalR connection is up right now. The trip is still tracked
  /// when it isn't — [RideFlowNotifier] falls back to REST polling — but the
  /// tracking screen says so, rather than showing a frozen car.
  final bool realtimeConnected;

  final bool isLoading;
  final String? error;

  bool get hasRoute => pickup != null && dropoff != null;

  RideFlowState copyWith({
    Place? pickup,
    Place? dropoff,
    DirectionsResult? route,
    double? distanceMiles,
    int? durationMinutes,
    String? selectedOptionId,
    Trip? activeTrip,
    DriverLocation? driverLocation,
    List<ChatMessage>? chatMessages,
    bool? realtimeConnected,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearTrip = false,
  }) =>
      RideFlowState(
        pickup: pickup ?? this.pickup,
        dropoff: dropoff ?? this.dropoff,
        route: route ?? this.route,
        distanceMiles: distanceMiles ?? this.distanceMiles,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        selectedOptionId: selectedOptionId ?? this.selectedOptionId,
        activeTrip: clearTrip ? null : (activeTrip ?? this.activeTrip),
        // Clearing the trip clears the car with it — a stale marker left on the
        // map after the ride ends is worse than no marker.
        driverLocation:
            clearTrip ? null : (driverLocation ?? this.driverLocation),
        chatMessages: clearTrip ? const [] : (chatMessages ?? this.chatMessages),
        realtimeConnected: realtimeConnected ?? this.realtimeConnected,
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
    DirectionsResult? route,
    double? distanceMiles,
    int? durationMinutes,
  }) {
    state = state.copyWith(
      pickup: pickup,
      dropoff: dropoff,
      route: route,
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
      state = state.copyWith(isLoading: false);
      // Through the funnel like every other trip update, so the invariant holds
      // everywhere: one path in, milestones counted once.
      _applyTrip(trip);
      unawaited(_startRealtime(trip.id));
      return trip;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
      return null;
    }
  }

  /// Joins the trip's SignalR group so `tripUpdated` pushes (driver assigned,
  /// arrived, started, completed, cancelled) update [RideFlowState.activeTrip]
  /// live, and `driverLocation` pushes move the car on the map.
  ///
  /// Realtime is the *fast* path, never the only one. [_startWatchdog] runs a
  /// REST poll alongside it for as long as the trip is live. That is not
  /// belt-and-braces pedantry: this flow previously had no fallback at all
  /// (`refreshActiveTrip` existed but nothing ever called it), so anything that
  /// broke the socket — and in production, the proxy broke it once a minute —
  /// left the rider on "Finding your driver…" while a car was already outside,
  /// with no PIN and no way to find out.
  Future<void> _startRealtime(String tripId) async {
    _startWatchdog();

    final token = _ref.read(authTokenProvider);
    if (token == null) return;

    _rt.onConnectionChange = (connected) {
      if (mounted) state = state.copyWith(realtimeConnected: connected);
      // Coming back from a drop, the app has missed everything said while it was
      // away: catch up over REST rather than waiting for the next push.
      if (connected) unawaited(_catchUp());
      _startWatchdog();
    };

    await _rt.connect(token, {
      'tripUpdated': _onTripUpdated,
      'driverLocation': _onDriverLocation,
      'messageReceived': _onMessageReceived,
    });
    // joinTrip (not invoke) so the membership is replayed after a reconnect —
    // SignalR groups are per-connection-id and a reconnect mints a new one.
    await _rt.joinTrip(tripId);
  }

  // ── REST safety net ────────────────────────────────────────────────────────

  /// Poll cadence while the socket is down — the rider is waiting on a kerb, so
  /// a few seconds of staleness is the most that's acceptable. Matched to the
  /// driver app's own ~5s location-push cadence: polling faster than the driver
  /// reports cannot surface anything newer, it just costs requests.
  static const _pollWhenOffline = Duration(seconds: 3);

  /// Cadence while the socket is up. Still polls, because "connected" does not
  /// prove "subscribed": a client can hold a healthy connection and receive
  /// nothing, which is precisely the failure this whole path exists to survive.
  static const _pollWhenOnline = Duration(seconds: 15);

  Timer? _watchdog;

  /// Trips already alerted on arrival, so reopening the app doesn't re-announce
  /// a driver who arrived ten minutes ago.
  final Set<String> _arrivalAlerted = {};
  final Set<String> _assignAlerted = {};

  void _startWatchdog() {
    _watchdog?.cancel();
    if (!_shouldPoll) {
      _watchdog = null;
      return;
    }
    final every = state.realtimeConnected ? _pollWhenOnline : _pollWhenOffline;
    _watchdog = Timer(every, () {
      _watchdog = null;
      unawaited(_catchUp().whenComplete(_startWatchdog));
    });
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  /// A trip that can still change is worth polling for; one that's finished or
  /// cancelled is not.
  bool get _shouldPoll {
    final status = state.activeTrip?.status;
    if (status == null) return false;
    return status == TripStatus.requested || status.isActive;
  }

  /// One round of the safety net: the trip itself, plus the car's position once
  /// there is a driver to have one.
  Future<void> _catchUp() async {
    await refreshActiveTrip();
    final status = state.activeTrip?.status;
    if (status != null && status.isActive) await refreshDriverLocation();
  }

  /// Call when the app returns to the foreground. Android freezes sockets on a
  /// backgrounded app, and a rider waiting for a car is backgrounded by
  /// definition — so resuming has to re-establish realtime *and* re-read the
  /// trip, not assume the connection survived.
  Future<void> appResumed() async {
    final trip = state.activeTrip;
    if (trip == null || !_shouldPoll) return;
    await _catchUp();
    await _startRealtime(trip.id);
  }

  /// Attaches to a trip that's already running — the app was reopened mid-ride,
  /// so there's no [confirmTrip] call to have started realtime. Seeds the
  /// driver's position over REST (every push so far has been missed) and then
  /// joins the group for the rest.
  Future<void> resumeTrip(Trip trip) async {
    // If the trip is missing driver info, fetch the full trip entity
    Trip fullTrip = trip;
    if (fullTrip.driver == null && fullTrip.status.isActive) {
      try {
        fullTrip = await _repo.getTrip(trip.id);
      } catch (_) {}
    }
    if (mounted) {
      state = state.copyWith(clearError: true);
      _applyTrip(fullTrip);
    }
    await _startRealtime(fullTrip.id);
    await refreshDriverLocation();
  }

  /// Looks for a trip still in flight and re-attaches to it. Called on app
  /// start or login: without this, a rider whose app was killed mid-ride (which Android
  /// does freely to a backgrounded app) comes back to a "Where to?" home screen
  /// while their driver is en route or in progress, with no way back to the tracking map.
  ///
  /// Returns the resumed trip, or null if there's nothing in flight.
  Future<Trip?> resumeActiveTrip() async {
    if (state.activeTrip != null &&
        (state.activeTrip!.status == TripStatus.requested || state.activeTrip!.status.isActive)) {
      unawaited(_startRealtime(state.activeTrip!.id));
      unawaited(refreshDriverLocation());
      return state.activeTrip;
    }
    try {
      // 1. Direct active trip lookup (returns full driver/vehicle/PIN info)
      final direct = await _repo.getActiveTrip();
      if (direct != null && (direct.status == TripStatus.requested || direct.status.isActive)) {
        await resumeTrip(direct);
        return state.activeTrip ?? direct;
      }

      // 2. Fallback: check trip history and fetch full details
      final trips = await _repo.tripHistory();
      final live = trips.where((t) =>
          t.status == TripStatus.requested || t.status.isActive).toList();
      if (live.isEmpty) return null;

      // Most recently booked wins if the backend ever hands back more than one.
      final newest = live.reduce((a, b) =>
          (a.createdAt ?? DateTime(0)).isAfter(b.createdAt ?? DateTime(0))
              ? a
              : b);
      final trip = await _repo.getTrip(newest.id);
      await resumeTrip(trip);
      return state.activeTrip ?? trip;
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
      _applyTrip(trip);
    } catch (e) {
      if (kDebugMode) debugPrint('[ride] bad tripUpdated payload: $e');
    }
  }

  /// The one place an updated trip enters state, whichever path found it — a
  /// realtime push, a safety-net poll, or a resume. Milestone alerts hang off
  /// this single funnel rather than off the push handler, so the rider is told
  /// their driver has arrived even when the push never came.
  void _applyTrip(Trip trip) {
    if (!mounted) return;
    final before = state.activeTrip?.status;
    state = state.copyWith(activeTrip: trip);

    if (before != trip.status) {
      _announce(trip);
      // A finished trip has nothing left to poll for; a newly-live one does.
      _startWatchdog();
    }
  }

  /// Raises the on-device alert for a milestone the rider must not miss. Guarded
  /// per trip, so re-reading the same status (a poll and a push arriving
  /// together, or the app being reopened) announces it once only.
  void _announce(Trip trip) {
    final alerts = _ref.read(tripAlertsProvider);
    switch (trip.status) {
      case TripStatus.driverAssigned:
        if (_assignAlerted.add(trip.id)) {
          unawaited(alerts.driverOnTheWay(driverName: trip.driver?.name));
        }
      case TripStatus.driverArrived:
        if (_arrivalAlerted.add(trip.id)) {
          unawaited(alerts.driverArrived(
              driverName: trip.driver?.name, pin: trip.pin));
        }
      default:
        break;
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

  Future<void> _stopRealtime() {
    _stopWatchdog();
    return _rt.disconnect();
  }

  /// Re-reads the trip over REST. This is the safety net's workhorse — driven by
  /// [_startWatchdog] and by [appResumed], not left to screens to remember.
  Future<void> refreshActiveTrip() async {
    final id = state.activeTrip?.id;
    if (id == null) return;
    try {
      final trip = await _repo.getTrip(id);
      _applyTrip(trip);
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
      state = state.copyWith(isLoading: false);
      _applyTrip(trip);
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

  /// Loads the rider's most recently completed trip — what the completed and
  /// rate screens are about when they weren't reached by finishing a ride in
  /// this session (menu, deep link, app restart). Returns null when the rider
  /// has never completed one, or the call failed.
  ///
  /// This does **not** start realtime: the trip is over, there is nothing left
  /// to push.
  Future<Trip?> loadLastCompletedTrip() async {
    try {
      final trips = await _repo.tripHistory();
      final done =
          trips.where((t) => t.status == TripStatus.completed).toList();
      if (done.isEmpty) return null;

      DateTime finishedAt(Trip t) =>
          t.completedAt ?? t.createdAt ?? DateTime(0);
      final trip =
          done.reduce((a, b) => finishedAt(a).isAfter(finishedAt(b)) ? a : b);
      if (mounted) state = state.copyWith(activeTrip: trip, clearError: true);
      return trip;
    } catch (_) {
      return null;
    }
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
    _stopWatchdog();
    _rt.disconnect();
    super.dispose();
  }
}

final rideFlowProvider =
    StateNotifierProvider<RideFlowNotifier, RideFlowState>(
  (ref) => RideFlowNotifier(ref.watch(rideRepositoryProvider), ref),
);

/// Thrown when something asks for a price before the rider has set a route.
/// The route screens are gated on `hasRoute`, so this is a backstop, not a
/// user-facing path.
class NoRouteException implements Exception {
  const NoRouteException();
  @override
  String toString() => 'NoRouteException: no pickup/drop-off set';
}

/// Prices the current route **on-device** from the API's fare chart — no
/// per-route round-trip, so tier prices appear instantly. The chart is fetched
/// once and cached ([fareChartProvider]); this recomputes locally whenever the
/// route changes. The API re-prices authoritatively at booking from the same
/// chart, so the shown price matches the charged price.
///
/// Requires a real route. It used to substitute a default Canary Wharf → Tower
/// Bridge one, so opening choose-ride directly quoted confident prices for a
/// journey the rider had never asked for.
final rideQuoteProvider = FutureProvider.autoDispose<RideQuote>((ref) async {
  final flow = ref.watch(rideFlowProvider);
  final chart = await ref.watch(fareChartProvider.future);

  final pickup = flow.pickup;
  final dropoff = flow.dropoff;
  if (pickup == null || dropoff == null) throw const NoRouteException();

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
