// Sign-in must put the refresh token where the Dio interceptor reads it.
//
// `_applyAuth` used to write only the access token to `authTokenProvider`; the
// refresh token reached `refreshTokenProvider` solely via `restore()` on the
// NEXT launch. So a customer who had just signed in had nothing to renew with,
// and the first 401 an hour later signed them out - even mid-trip.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/network/api_client.dart';
import 'package:mapcars_mobile/src/features/auth/models/auth_session.dart';
import 'package:mapcars_mobile/src/features/auth/providers/auth_notifier.dart';
import 'package:mapcars_mobile/src/features/auth/services/customer_auth_service.dart';
import 'package:mapcars_mobile/src/features/auth/services/session_repository.dart';

/// Hands back a canned [AuthResult] instead of calling the API.
class _FakeAuthService extends CustomerAuthService {
  _FakeAuthService() : super(Dio());

  static const result = AuthResult(
    token: 'access-1',
    refreshToken: 'refresh-1',
    expiresInMinutes: 60,
    userId: 'u-1',
    email: 'ada@example.com',
    isProfileComplete: true,
    isEmailVerified: true,
    isPhoneVerified: false,
  );

  @override
  Future<AuthResult> loginWithEmail(String email, String password) async =>
      result;

  @override
  Future<AuthResult> verifyPhoneOtp(String phone, String code) async => result;

  @override
  Future<AuthResult> verifyEmailOtp(String email, String code) async => result;

  @override
  Future<AuthResult> signInWithGoogle(String idToken,
          {bool signUp = false}) async =>
      result;
}

/// Keeps the session in memory so no platform channel is touched.
class _MemorySessionRepository extends SessionRepository {
  _MemorySessionRepository() : super(const FlutterSecureStorage());

  AuthSession? saved;

  @override
  Future<void> save(AuthSession session) async => saved = session;

  @override
  Future<AuthSession?> load() async => saved;

  @override
  Future<void> clear() async => saved = null;
}

void main() {
  late _MemorySessionRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MemorySessionRepository();
    container = ProviderContainer(overrides: [
      customerAuthServiceProvider.overrideWithValue(_FakeAuthService()),
      sessionRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
  });

  test('email sign-in stores both tokens for the Dio interceptor', () async {
    final ok = await container
        .read(authNotifierProvider.notifier)
        .loginWithEmail('ada@example.com', 'pw');

    expect(ok, isTrue);
    expect(container.read(authTokenProvider), 'access-1');
    expect(container.read(refreshTokenProvider), 'refresh-1');
  });

  test('Google and email-OTP sign-in store the refresh token too', () async {
    final notifier = container.read(authNotifierProvider.notifier);

    await notifier.signInWithGoogle('id-token');
    expect(container.read(refreshTokenProvider), 'refresh-1');

    container.read(refreshTokenProvider.notifier).state = null;
    await notifier.verifyEmailOtp('ada@example.com', '123456');
    expect(container.read(refreshTokenProvider), 'refresh-1');
  });

  test('the persisted session carries the refresh token for restore()',
      () async {
    await container
        .read(authNotifierProvider.notifier)
        .loginWithEmail('ada@example.com', 'pw');

    expect(repo.saved?.refreshToken, 'refresh-1');
  });
}
