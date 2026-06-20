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
