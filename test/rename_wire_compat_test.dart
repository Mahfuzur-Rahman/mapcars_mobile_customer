// Wire compatibility across the Rider -> Customer rename.
//
// The API speaks the old vocabulary until migration 031 and the new one after,
// and a mobile build cannot be swapped in at that moment — a store release is
// days. So this build has to understand both, with no release in between.
//
// Every case below fails SILENTLY rather than throwing, which is why it is
// pinned rather than trusted:
//
//   * a sender type that stops matching renders your own messages as the
//     driver's, so the chat reads as though someone else said your words;
//   * a status falling through to `unknown` leaves a cancelled trip on screen
//     looking live, with the customer still waiting for a car;
//   * an id read from the wrong key gives the profile the string "null";
//   * a renamed storage key signs the user out on upgrade.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/features/auth/services/customer_auth_service.dart';
import 'package:mapcars_mobile/src/features/ride/models/chat_message.dart';
import 'package:mapcars_mobile/src/features/ride/models/trip_status.dart';

Map<String, dynamic> _msgJson(String senderType) => {
      'id': 'm1',
      'tripId': 't1',
      'senderType': senderType,
      'senderId': 's1',
      'content': 'I am at the blue door',
      'sentAtUtc': '2026-09-01T12:00:00Z',
    };

void main() {
  group('chat sender type', () {
    test('the legacy passenger spelling is folded onto the new one', () {
      expect(ChatMessage.fromJson(_msgJson('rider')).senderType, 'customer');
    });

    test('the new spelling passes through unchanged', () {
      expect(ChatMessage.fromJson(_msgJson('customer')).senderType, 'customer');
    });

    test('driver is untouched by the folding', () {
      expect(ChatMessage.fromJson(_msgJson('driver')).senderType, 'driver');
    });

    test('my own message is mine under EITHER spelling', () {
      // In this app the customer is "me", so this is what decides which side of
      // the conversation a bubble is drawn on.
      for (final wire in ['rider', 'customer']) {
        expect(
          ChatMessage.fromJson(_msgJson(wire)).senderType == 'customer',
          isTrue,
          reason: 'sender type "$wire" should have been recognised as mine',
        );
      }
    });

    test('a driver message is never counted as mine', () {
      expect(ChatMessage.fromJson(_msgJson('driver')).senderType == 'customer',
          isFalse);
    });
  });

  group('trip status', () {
    test('both cancelled-by-passenger spellings parse to the same state', () {
      expect(TripStatus.fromApi('CancelledByRider'),
          TripStatus.cancelledByCustomer);
      expect(TripStatus.fromApi('CancelledByCustomer'),
          TripStatus.cancelledByCustomer);
    });

    test('the parser stays case- and underscore-insensitive for both', () {
      // fromApi lowercases and strips underscores before matching; keep that
      // true for the new spelling as well as the old.
      expect(TripStatus.fromApi('cancelled_by_customer'),
          TripStatus.cancelledByCustomer);
      expect(TripStatus.fromApi('CANCELLED_BY_RIDER'),
          TripStatus.cancelledByCustomer);
    });

    test('an unrecognised status is still unknown, not a crash', () {
      expect(TripStatus.fromApi('SomethingNew'), TripStatus.unknown);
      expect(TripStatus.fromApi(null), TripStatus.unknown);
    });
  });

  group('profile id', () {
    Map<String, dynamic> base(Map<String, dynamic> extra) => {
          'fullName': 'Ada',
          ...extra,
        };

    test('reads the new key', () {
      expect(CustomerProfile.fromJson(base({'customerId': 'c1'})).customerId,
          'c1');
    });

    test('falls back to the legacy key', () {
      expect(
          CustomerProfile.fromJson(base({'riderId': 'r1'})).customerId, 'r1');
    });

    test('prefers the new key when the API sends both', () {
      expect(
        CustomerProfile.fromJson(base({'customerId': 'c1', 'riderId': 'r1'}))
            .customerId,
        'c1',
      );
    });
  });
}
