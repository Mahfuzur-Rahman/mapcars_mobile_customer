import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/trip_alerts.dart';
import 'models/chat_message.dart';

/// Banner + sound for a message nobody is reading. Foreground-only by design
/// (see `TripAlerts.driverMessage`): in the background the server's push shows it.
Future<void> showChatAlert(Ref ref, ChatMessage message, String? senderName) =>
    ref.read(tripAlertsProvider).driverMessage(
          tripId: message.tripId,
          text: message.content,
          driverName: senderName,
        );
