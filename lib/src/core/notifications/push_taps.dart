import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ride/providers/ride_flow_notifier.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import 'push_routing.dart';
import 'trip_alerts.dart';

/// Opens the screen a tapped notification is about.
///
/// Taps arrive three ways, and all of them end up in [_open]:
///  * **backgrounded** — FCM's `onMessageOpenedApp`;
///  * **killed** — FCM's `getInitialMessage`, or the launch details of one of
///    the app's own [TripAlerts];
///  * **foreground** — a tapped [TripAlerts] banner. FCM messages that arrive
///    in the foreground are not re-shown as notifications on purpose: the open
///    app already reacts to the same event live, and the milestones a customer
///    must not miss are raised locally by the ride flow — a second banner for
///    each would just be a duplicate.
///
/// Nothing is opened until the splash calls [becomeReady]. Before then there
/// is no restored session to know whether the customer is signed in, and the
/// splash is about to `go()` somewhere itself — navigating first would lose
/// that race and strand the customer on whichever screen the splash chose.
class PushTaps {
  PushTaps(this._ref);
  final Ref _ref;

  bool _listening = false;
  bool _ready = false;
  bool _draining = false;
  PushTarget? _pending;

  /// Resolves once the killed-state taps have been read (or given up on).
  Future<void>? _launchRead;

  /// Wires up every tap source. Idempotent; called once from `MapcarsApp`.
  void listen() {
    if (_listening) return;
    _listening = true;

    _ref.read(tripAlertsProvider).onTap = handle;

    // Firebase is optional per build (no google-services.json → no push at
    // all), and touching FirebaseMessaging without it throws.
    final hasFirebase = Firebase.apps.isNotEmpty;
    if (hasFirebase) {
      FirebaseMessaging.onMessageOpenedApp.listen((m) => handle(m.data));
    }
    _launchRead = _readLaunchTap(hasFirebase);
  }

  Future<void> _readLaunchTap(bool hasFirebase) async {
    try {
      Map<String, dynamic>? data;
      if (hasFirebase) {
        data = (await FirebaseMessaging.instance.getInitialMessage())?.data;
      }
      data ??= await _ref.read(tripAlertsProvider).launchTap();
      // Too late to count as the launch tap (becomeReady gave up waiting):
      // jumping screens seconds after the customer started using the app
      // would be worse than not following the tap at all.
      if (data != null && !_ready) _pending = pushTargetFor(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[push] launch tap unreadable: $e');
    }
  }

  /// A notification was tapped. Routed now if the app is ready, otherwise held
  /// until it is — the latest tap wins.
  void handle(Map<String, dynamic> data) {
    final target = pushTargetFor(data);
    if (target == null) return; // unknown payload: opening the app is enough
    _pending = target;
    if (_ready) unawaited(_drain());
  }

  /// Called by the splash once the session is restored. Opens a tap that
  /// launched the app (consuming it — it is never replayed) and lets later
  /// taps through immediately.
  ///
  /// Returns true if it navigated, in which case the splash must not.
  Future<bool> becomeReady() async {
    listen();
    // Bounded: a platform channel that never answers must not hold the
    // customer on the splash forever.
    await _launchRead?.timeout(const Duration(seconds: 3), onTimeout: () {});
    _ready = true;
    return _drain();
  }

  Future<bool> _drain() async {
    if (_draining) return false; // the running drain picks up the new tap
    _draining = true;
    var opened = false;
    try {
      while (_pending != null) {
        final target = _pending!;
        _pending = null;
        opened = await _open(target) || opened;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[push] tap routing failed: $e');
    } finally {
      _draining = false;
    }
    return opened;
  }

  Future<bool> _open(PushTarget target) async {
    // Signed out: every destination is a signed-in screen. The auth guard
    // would bounce it to /intro anyway; not navigating at all is quieter.
    if (_ref.read(authTokenProvider) == null) return false;

    final flow = _ref.read(rideFlowProvider.notifier);
    await flow
        .syncTripForPush(target.tripId)
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    // The re-read can itself end the session (a 401 the refresher couldn't
    // save), in which case the router is already on its way to /intro.
    if (_ref.read(authTokenProvider) == null) return false;

    final trip = _ref.read(rideFlowProvider).activeTrip;
    final route = settledPushRoute(
      target,
      trip?.id == target.tripId ? trip!.status : null,
    );

    final router = _ref.read(routerProvider);
    // Already there (e.g. a chat push tapped while reading that chat): the
    // sync above has refreshed what the screen shows; re-navigating would only
    // rebuild it.
    if (router.routerDelegate.currentConfiguration.uri.path != route) {
      router.go(route);
    }
    return true;
  }
}

final pushTapsProvider = Provider<PushTaps>((ref) => PushTaps(ref));
