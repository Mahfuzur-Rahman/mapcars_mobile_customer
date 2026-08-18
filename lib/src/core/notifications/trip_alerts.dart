import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On-device alerts for the two trip moments a rider must not miss: a driver
/// accepting, and a driver arriving with the PIN to read out.
///
/// This is deliberately **local**, not FCM. Server push depends on a Firebase
/// service-account file being mounted on the API host, and while that is absent
/// the API silently falls back to a console stub — so "your driver has arrived"
/// never leaves the server. A local notification is raised by the app itself the
/// moment it observes the status change (over realtime *or* the REST safety-net
/// poll), so it is correct regardless of server-side push. FCM remains the path
/// that covers a fully-closed app; the two are complementary, not alternatives.
///
/// Every call is best-effort: an alert failing must never disturb the ride.
class TripAlerts {
  static const _channelId = 'mapcars_trip';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));

      // Max importance so Android renders it as a heads-up banner over whatever
      // the rider is doing. A quiet tray entry is no use to someone standing at
      // a kerb wondering where their car is.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Trip updates',
            description: 'Driver accepted, driver arrived, and your meet-up PIN.',
            importance: Importance.max,
          ));
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[alerts] init failed: $e');
    }
  }

  /// The driver is at the pickup. [pin] is shown in the notification body so the
  /// rider has it without unlocking into the app.
  Future<void> driverArrived({String? driverName, String? pin}) => _show(
        id: 8801,
        title: '${driverName ?? 'Your driver'} has arrived',
        body: pin == null
            ? 'Head out to meet your driver.'
            : 'Head out and give them PIN $pin to start the trip.',
      );

  /// A driver took the job and is now driving to the pickup.
  Future<void> driverOnTheWay({String? driverName, String? etaLabel}) => _show(
        id: 8802,
        title: '${driverName ?? 'A driver'} is on the way',
        body: etaLabel == null
            ? 'Your driver is heading to your pickup.'
            : 'Arriving in about $etaLabel.',
      );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureReady();
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Trip updates',
            importance: Importance.max,
            priority: Priority.high,
            // The rider may be looking at the phone already; a banner alone can
            // be missed on a bright street.
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      await HapticFeedback.heavyImpact();
    } catch (e) {
      if (kDebugMode) debugPrint('[alerts] show failed: $e');
    }
  }
}

final tripAlertsProvider = Provider<TripAlerts>((ref) => TripAlerts());
