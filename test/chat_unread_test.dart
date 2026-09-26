// The unread-message rule and its badge.
//
// Chat was previously invisible until opened: a driver asking "which entrance?"
// got silence unless the customer happened to look. These pin the two ways that
// could go wrong in the other direction — badging your own messages, or badging
// a conversation the customer is already reading.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/widgets/mc.dart';
import 'package:mapcars_mobile/src/features/ride/models/chat_message.dart';

ChatMessage _msg(String senderType) => ChatMessage(
      id: 'm1',
      tripId: 't1',
      senderType: senderType,
      senderId: 's1',
      content: 'Which entrance?',
      sentAtUtc: DateTime.utc(2026, 9, 1, 12),
    );

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('unreadAfter (customer app: the other party is the driver)', () {
    test("counts the driver's message when chat is closed", () {
      expect(
        unreadAfter(
            current: 0,
            message: _msg('driver'),
            otherParty: 'driver',
            chatOpen: false),
        1,
      );
    });

    test('ignores it while the customer is reading the conversation', () {
      expect(
        unreadAfter(
            current: 3,
            message: _msg('driver'),
            otherParty: 'driver',
            chatOpen: true),
        3,
      );
    });

    test("never counts the customer's own message", () {
      // sendMessage appends optimistically and the push echoes back; badging
      // either would put a count on your own text.
      expect(
        unreadAfter(
            current: 2,
            message: _msg('customer'),
            otherParty: 'driver',
            chatOpen: false),
        2,
      );
    });

    test('accumulates across several messages', () {
      var n = 0;
      for (var i = 0; i < 4; i++) {
        n = unreadAfter(
            current: n,
            message: _msg('driver'),
            otherParty: 'driver',
            chatOpen: false);
      }
      expect(n, 4);
    });
  });

  group('McBadge', () {
    testWidgets('draws nothing at zero', (tester) async {
      await tester.pumpWidget(
        _host(const McBadge(count: 0, child: Text('Message driver'))),
      );

      expect(find.text('Message driver'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the count', (tester) async {
      await tester.pumpWidget(
        _host(const McBadge(count: 3, child: Text('Message driver'))),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps at 9+ so the bubble cannot grow unbounded',
        (tester) async {
      await tester.pumpWidget(
        _host(const McBadge(count: 42, child: Text('Message driver'))),
      );

      expect(find.text('9+'), findsOneWidget);
      expect(find.text('42'), findsNothing);
    });

    testWidgets('the bubble itself is not announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(McBadge(
          count: 3,
          child: McGhostButton(
            'Message driver',
            semanticLabel: 'Message driver, 3 unread',
            onTap: () {},
          ),
        )),
      );

      // A bare "3" read out beside a button is not information — the count
      // reaches the reader through the button's own label instead.
      expect(find.bySemanticsLabel('3'), findsNothing);
      final node = tester.getSemantics(find.byType(McGhostButton));
      expect(node.label, 'Message driver, 3 unread');
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);

      handle.dispose();
    });
  });
}
