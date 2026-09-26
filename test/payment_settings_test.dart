// Which payment methods the booking sheet offers.
//
// The rule lives in the model rather than the widget so it can be stated once
// and tested. Every case here is one where getting it wrong produces a booking
// sheet that is quietly unusable rather than visibly broken: a method on offer
// that the server will reject, a preselection that is not among the options, or
// — worst — no way to pay at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/features/ride/models/payment_settings.dart';

PaymentSettings _s({bool cash = true, bool card = false, String def = 'Cash'}) =>
    PaymentSettings.fromJson({
      'cashEnabled': cash,
      'cardEnabled': card,
      'defaultMethod': def,
    });

void main() {
  group('parsing', () {
    test('lowercases the default method to match what the booking flow sends', () {
      expect(_s(def: 'Card', card: true).defaultMethod, 'card');
      expect(_s(def: 'Cash').defaultMethod, 'cash');
    });

    test('missing fields fall back to cash-only, never to card', () {
      final s = PaymentSettings.fromJson(<String, dynamic>{});
      expect(s.cashEnabled, isTrue);
      expect(s.cardEnabled, isFalse);
      expect(s.defaultMethod, 'cash');
    });

    test('the offline fallback is cash-only', () {
      // If we cannot reach the API we do not know whether card is on. Offering a
      // disabled method produces a booking the server rejects.
      expect(PaymentSettings.fallback.cardEnabled, isFalse);
      expect(PaymentSettings.fallback.available, ['cash']);
    });
  });

  group('available methods', () {
    test('both on gives cash first, then card', () {
      expect(_s(cash: true, card: true).available, ['cash', 'card']);
    });

    test('cash only', () => expect(_s(cash: true, card: false).available, ['cash']));
    test('card only', () => expect(_s(cash: false, card: true).available, ['card']));

    test('never empty, even if the server somehow disables both', () {
      // The API refuses to disable both — but a client that trusted that and was
      // wrong would render a booking sheet with no way to pay at all.
      final s = _s(cash: false, card: false);
      expect(s.available, isNotEmpty);
      expect(s.available, ['cash']);
    });
  });

  group('preselection', () {
    test('honours the admin default when it is actually offerable', () {
      expect(_s(cash: true, card: true, def: 'Card').preselected, 'card');
      expect(_s(cash: true, card: true, def: 'Cash').preselected, 'cash');
    });

    test('falls back when the default names a disabled method', () {
      // The API corrects this on write, but a stale cached copy could still hold
      // the old pair — and preselecting an unavailable method would leave the
      // sheet with nothing highlighted.
      expect(_s(cash: true, card: false, def: 'Card').preselected, 'cash');
      expect(_s(cash: false, card: true, def: 'Cash').preselected, 'card');
    });

    test('the preselection is always one of the available methods', () {
      for (final cash in [true, false]) {
        for (final card in [true, false]) {
          for (final def in ['Cash', 'Card']) {
            final s = _s(cash: cash, card: card, def: def);
            expect(s.available, contains(s.preselected),
                reason: 'cash=$cash card=$card default=$def');
          }
        }
      }
    });
  });

  group('hasChoice', () {
    test('false with one method, so the chooser becomes a line of text', () {
      expect(_s(cash: true, card: false).hasChoice, isFalse);
      expect(_s(cash: false, card: true).hasChoice, isFalse);
    });

    test('true with both', () => expect(_s(cash: true, card: true).hasChoice, isTrue));
  });
}
