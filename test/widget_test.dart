// Unit tests for the auth session model and the AuthState <-> AuthSession
// mapping that backs persisted login. These cover the production-grade session
// logic (serialization, expiry) without needing platform secure storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/features/auth/models/auth_session.dart';
import 'package:mapcars_mobile/src/features/auth/models/auth_state.dart';

void main() {
  group('AuthSession', () {
    final session = AuthSession(
      token: 'jwt-123',
      expiresAt: DateTime.utc(2030, 1, 1, 12),
      userId: 'rider-1',
      fullName: 'Alex Morgan',
      email: 'alex@email.com',
      phone: '+447700900000',
      isProfileComplete: true,
      isEmailVerified: true,
      isPhoneVerified: true,
    );

    test('survives a JSON encode/decode round-trip', () {
      final decoded = AuthSession.decode(session.encode());

      expect(decoded.token, session.token);
      expect(decoded.expiresAt, session.expiresAt);
      expect(decoded.userId, session.userId);
      expect(decoded.fullName, session.fullName);
      expect(decoded.email, session.email);
      expect(decoded.phone, session.phone);
      expect(decoded.isProfileComplete, isTrue);
      expect(decoded.isEmailVerified, isTrue);
      expect(decoded.isPhoneVerified, isTrue);
    });

    test('carries the refresh token through a round-trip', () {
      // The refresh token is what keeps the user signed in past the access
      // token's one-hour life, so losing it in storage would silently restore
      // the old "log in every hour" behaviour.
      final withRefresh = AuthSession(
        token: 'jwt-123',
        refreshToken: 'refresh-abc',
        expiresAt: DateTime.utc(2030, 1, 1, 12),
        userId: 'u',
        isProfileComplete: false,
        isEmailVerified: false,
        isPhoneVerified: false,
      );

      expect(AuthSession.decode(withRefresh.encode()).refreshToken, 'refresh-abc');
    });

    test('tolerates a session persisted before refresh tokens existed', () {
      // Sessions already on disk have no refreshToken key. Decoding must not
      // throw - it should just yield null and let the normal expiry path run.
      const legacy = '{"token":"t","expiresAt":"2030-01-01T12:00:00.000Z",'
          '"userId":"u","isProfileComplete":false,"isEmailVerified":false,'
          '"isPhoneVerified":false}';

      final decoded = AuthSession.decode(legacy);
      expect(decoded.refreshToken, isNull);
      expect(decoded.token, 't');
    });

    test('isExpired reflects the expiry timestamp', () {
      final past = AuthSession(
        token: 't',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        userId: 'u',
        isProfileComplete: false,
        isEmailVerified: false,
        isPhoneVerified: false,
      );
      final future = AuthSession(
        token: 't',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        userId: 'u',
        isProfileComplete: false,
        isEmailVerified: false,
        isPhoneVerified: false,
      );

      expect(past.isExpired, isTrue);
      expect(future.isExpired, isFalse);
    });
  });

  group('AuthState', () {

    test('keeps the refresh token across fromSession / toSession', () {
      final session = AuthSession(
        token: 'jwt',
        refreshToken: 'refresh-xyz',
        expiresAt: DateTime.utc(2030, 6, 1),
        userId: 'u',
        isProfileComplete: false,
        isEmailVerified: false,
        isPhoneVerified: false,
      );

      expect(AuthState.fromSession(session).refreshToken, 'refresh-xyz');
      expect(AuthState.fromSession(session).toSession()?.refreshToken, 'refresh-xyz');
    });
    test('toSession returns null when not authenticated', () {
      expect(const AuthState().toSession(), isNull);
    });

    test('round-trips through fromSession / toSession', () {
      final session = AuthSession(
        token: 'jwt',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        userId: 'rider-9',
        fullName: 'Sam',
        isProfileComplete: true,
        isEmailVerified: false,
        isPhoneVerified: true,
      );

      final state = AuthState.fromSession(session);
      expect(state.isAuthenticated, isTrue);
      expect(state.userId, 'rider-9');

      final back = state.toSession();
      expect(back, isNotNull);
      expect(back!.token, 'jwt');
      expect(back.isProfileComplete, isTrue);
    });

    test('isAuthenticated is false once the token has expired', () {
      final expired = AuthState(
        token: 'jwt',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        userId: 'r',
      );
      expect(expired.isExpired, isTrue);
      expect(expired.isAuthenticated, isFalse);
    });
  });
}
