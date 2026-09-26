import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_store.dart';
import '../models/auth_session.dart';

/// Persists the authenticated customer session to secure storage so the user
/// stays signed in across app restarts.
class SessionRepository {
  SessionRepository(this._store);

  final FlutterSecureStorage _store;
  static const _key = 'customer_session_v1';

  /// What this key was called before the Rider -> Customer rename.
  ///
  /// Renaming a storage key silently signs out everyone who already has a
  /// session, and "I opened the app and it had forgotten me" is a bad first
  /// impression of a release whose entire user-visible change is a word. The
  /// migration below costs ten lines and removes that entirely.
  ///
  /// Delete once no build older than the rename is installed anywhere.
  static const _legacyKey = 'rider_session_v1';

  Future<void> save(AuthSession session) =>
      _store.write(key: _key, value: session.encode());

  Future<AuthSession?> load() async {
    final raw = await _store.read(key: _key) ?? await _migrateLegacy();
    if (raw == null) return null;
    try {
      return AuthSession.decode(raw);
    } catch (_) {
      // Corrupt or schema-changed payload — drop it rather than crash on boot.
      await clear();
      return null;
    }
  }

  /// Moves a pre-rename session onto the current key, returning what it found.
  /// Runs at most once per install: the old entry is deleted as soon as it has
  /// been copied across.
  Future<String?> _migrateLegacy() async {
    final legacy = await _store.read(key: _legacyKey);
    if (legacy == null) return null;
    await _store.write(key: _key, value: legacy);
    await _store.delete(key: _legacyKey);
    return legacy;
  }

  Future<void> clear() async {
    await _store.delete(key: _key);
    // Retire the pre-rename entry too, or signing out would leave behind a
    // session the migration above would cheerfully restore on next launch.
    await _store.delete(key: _legacyKey);
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(secureStoreProvider)),
);
