// Upgrading must not sign anyone out (the session moves to the new key and
// options), and unreadable storage must not hang the splash.

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/features/auth/models/auth_session.dart';
import 'package:mapcars_mobile/src/features/auth/services/session_repository.dart';

/// A store whose every read fails, as a Keystore-bound value does after a
/// backup restore, or a keychain item does while the phone is locked.
class _UnreadableStore extends FlutterSecureStorage {
  const _UnreadableStore();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      throw PlatformException(code: 'unreadable');
}

final _session = AuthSession(
  token: 'access-1',
  refreshToken: 'refresh-1',
  expiresAt: DateTime.utc(2030),
  userId: 'u-1',
  isProfileComplete: true,
  isEmailVerified: true,
  isPhoneVerified: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a session saved by an older build is carried onto the new key', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'customer_session_v1': _session.encode()});
    const store = FlutterSecureStorage();

    final loaded = await SessionRepository(store, store).load();

    expect(loaded?.refreshToken, 'refresh-1');
    final all = await store.readAll();
    expect(all.containsKey('customer_session_v2'), isTrue);
    expect(all.containsKey('customer_session_v1'), isFalse);
  });

  test('a pre-rename rider session is still carried across', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'rider_session_v1': _session.encode()});
    const store = FlutterSecureStorage();

    final loaded = await SessionRepository(store, store).load();

    expect(loaded?.userId, 'u-1');
    expect((await store.readAll()).keys, ['customer_session_v2']);
  });

  test('sign-out clears every generation of the key', () async {
    FlutterSecureStorage.setMockInitialValues({
      'customer_session_v2': _session.encode(),
      'customer_session_v1': _session.encode(),
      'rider_session_v1': _session.encode(),
    });
    const store = FlutterSecureStorage();

    await SessionRepository(store, store).clear();

    expect(await store.readAll(), isEmpty);
  });

  test('unreadable storage reads as signed out instead of throwing', () async {
    const store = _UnreadableStore();

    expect(await SessionRepository(store, store).load(), isNull);
  });
}
