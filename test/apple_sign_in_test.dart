// Sign in with Apple: the nonce and name handling the API relies on.
//
// The API accepts an Apple identity token only if the token's `nonce` claim
// equals SHA-256(hex) of the raw nonce the app sends alongside it. Get the two
// forms the wrong way round and every Apple sign-in is refused.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/features/auth/services/apple_sign_in_service.dart';

void main() {
  group('sha256OfNonce', () {
    test('is lower-case hex SHA-256 of the raw string', () {
      // Known vector: SHA-256("abc").
      expect(
        sha256OfNonce('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('is 64 hex characters for any raw nonce', () {
      expect(sha256OfNonce(generateRawNonce()), matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('generateRawNonce', () {
    test('encodes 32 random bytes as unpadded base64url', () {
      final nonce = generateRawNonce();
      // 32 bytes → 43 base64 characters once the single "=" pad is dropped.
      expect(nonce.length, 43);
      expect(nonce, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('is different every time', () {
      final seen = {for (var i = 0; i < 200; i++) generateRawNonce()};
      expect(seen.length, 200);
    });

    test('draws every byte from the given generator', () {
      // Seeded generators make the output reproducible — proof the bytes come
      // from the RNG passed in, which in production is Random.secure().
      expect(generateRawNonce(random: Random(7)), generateRawNonce(random: Random(7)));
      expect(generateRawNonce(random: Random(7)), isNot(generateRawNonce(random: Random(8))));
    });
  });

  group('appleFullName', () {
    test('joins the parts Apple sends on the first authorisation', () {
      expect(appleFullName('Ada', 'Lovelace'), 'Ada Lovelace');
      expect(appleFullName(' Ada ', null), 'Ada');
      expect(appleFullName(null, 'Lovelace'), 'Lovelace');
    });

    test('is null, not empty, when Apple sends no name (every later sign-in)', () {
      expect(appleFullName(null, null), isNull);
      expect(appleFullName('', '  '), isNull);
    });
  });
}
