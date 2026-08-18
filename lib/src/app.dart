import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/ride/providers/ride_flow_notifier.dart';

class MapcarsApp extends ConsumerStatefulWidget {
  const MapcarsApp({super.key});

  @override
  ConsumerState<MapcarsApp> createState() => _MapcarsAppState();
}

class _MapcarsAppState extends ConsumerState<MapcarsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Android suspends a backgrounded app's sockets, and a rider waiting for a
  /// car spends most of that wait with the app behind something else or the
  /// screen off. Coming back has to re-read the trip and re-establish realtime;
  /// assuming the connection survived is how riders returned to a stale
  /// "Finding your driver…" with a car already outside.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(rideFlowProvider.notifier).appResumed();
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
      } else if (next == null && prev != null) {
        push.unregister();
      }
    });

    return MaterialApp.router(
      title: 'Mapcars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
