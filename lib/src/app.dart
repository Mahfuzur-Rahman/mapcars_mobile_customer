import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/notifications/push_service.dart';
import 'core/notifications/push_taps.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/updates/update_nudge.dart';
import 'core/widgets/offline_banner.dart';
import 'features/messages/models/chat_message.dart';
import 'features/messages/providers/chat_inbox.dart';
import 'features/messages/providers/unread_provider.dart';
import 'features/ride/providers/ride_flow_notifier.dart';

class MapcarsApp extends ConsumerStatefulWidget {
  const MapcarsApp({super.key});

  @override
  ConsumerState<MapcarsApp> createState() => _MapcarsAppState();
}

class _MapcarsAppState extends ConsumerState<MapcarsApp>
    with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _fcm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Subscribed from the first frame so no tap is missed; acting on them waits
    // for the splash to finish restoring the session (see PushTaps).
    ref.read(pushTapsProvider).listen();
    _listenForChatPushes();
  }

  /// Android shows nothing for an FCM message while the app is open — it only
  /// reaches `onMessage`. Before this the customer app didn't listen at all, so
  /// a driver's message about a past trip (lost umbrella) arrived in silence.
  /// The push carries the whole message; the inbox de-duplicates it against
  /// SignalR, raises the banner and bumps the badge.
  void _listenForChatPushes() {
    try {
      _fcm = FirebaseMessaging.onMessage.listen((message) {
        if (message.data['type'] != 'messageReceived') return;
        final msg = ChatMessage.fromPushData(message.data);
        if (msg != null) {
          ref.read(chatInboxProvider).receive(msg);
        } else {
          ref.read(unreadProvider.notifier).refresh();
        }
      });
    } catch (e) {
      // No Firebase in this build — SignalR and resume refresh still work.
      if (kDebugMode) debugPrint('[push] chat listener skipped: $e');
    }
  }

  @override
  void dispose() {
    _fcm?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Android suspends a backgrounded app's sockets, and a customer waiting for a
  /// car spends most of that wait with the app behind something else or the
  /// screen off. Coming back has to re-read the trip and re-establish realtime;
  /// assuming the connection survived is how customers returned to a stale
  /// "Finding your driver…" with a car already outside.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(rideFlowProvider.notifier).appResumed();
      // Anything sent while the app was away arrived as a tray notification,
      // not through the inbox — re-read the badge from the server.
      if (ref.read(authTokenProvider) != null) {
        ref.read(unreadProvider.notifier).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Register/unregister this device for push as the auth session comes and
    // goes (token null → signed in → registers; back to null → unregisters).
    ref.listen<String?>(authTokenProvider, (prev, next) {
      final push = ref.read(pushServiceProvider);
      if (next != null && prev == null) {
        push.registerAndListen();
        ref.read(unreadProvider.notifier).refresh();
      } else if (next == null && prev != null) {
        push.unregister();
        ref.read(unreadProvider.notifier).reset();
      }
    });

    return MaterialApp.router(
      title: 'Mapcars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
      // Installed once here so every screen gets the offline bar — the screens
      // where it matters most (waiting for a car, mid-ride) are the ones nobody
      // would remember to opt in.
      builder: (context, child) =>
          UpdateNudge(
            child: OfflineBanner(child: child ?? const SizedBox.shrink())),
    );
  }
}
