import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thrown when the Apple flow can't produce a credential. The message is
/// user-facing — screens show it in the standard error banner.
class AppleSignInFailure implements Exception {
  const AppleSignInFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What `POST /api/v1/auth/customers/apple` needs from one Apple sign-in.
class AppleCredential {
  const AppleCredential({
    required this.idToken,
    required this.rawNonce,
    this.fullName,
  });

  final String idToken;

  /// The nonce **before** hashing. Apple embeds sha256(raw) in the token; the
  /// API recomputes that from this value, which is what binds the token to
  /// this one attempt and makes a captured token useless for a replay.
  final String rawNonce;

  /// Only present on the customer's *first* authorisation for this app — Apple
  /// never sends the name again, so a missed one is gone for good.
  final String? fullName;
}

/// A fresh, unguessable nonce: [bytes] from the platform CSPRNG, base64url
/// without padding (so it is URL/JSON-safe as-is).
String generateRawNonce({int bytes = 32, Random? random}) {
  final rng = random ?? Random.secure();
  final data = List<int>.generate(bytes, (_) => rng.nextInt(256));
  return base64Url.encode(data).replaceAll('=', '');
}

/// Lower-case hex SHA-256 of [raw] — the form Apple is given, and the form the
/// API compares the token's `nonce` claim against.
String sha256OfNonce(String raw) => sha256.convert(utf8.encode(raw)).toString();

/// Joins Apple's name parts, or null when Apple sent none (every sign-in after
/// the first). Null rather than "" so the API keeps whatever name it has.
String? appleFullName(String? givenName, String? familyName) {
  final parts = [givenName, familyName]
      .map((p) => p?.trim() ?? '')
      .where((p) => p.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' ');
}

/// Wraps the native Sign in with Apple sheet.
///
/// iOS only. App Review guideline 4.8 requires it there because Google sign-in
/// is offered; on Android it would need a web-flow Service ID for no one who
/// asked, so the button is simply not shown ([isAvailable]).
class AppleSignInService {
  static bool get isAvailable => !kIsWeb && Platform.isIOS;

  /// Opens the Apple sheet.
  ///
  /// Returns `null` if the customer backed out (not an error — screens stay
  /// put). Throws [AppleSignInFailure] for anything else.
  Future<AppleCredential?> obtainCredential() async {
    final rawNonce = generateRawNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256OfNonce(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      if (kDebugMode) debugPrint('[apple] sign-in failed: ${e.code} ${e.message}');
      throw const AppleSignInFailure(
        "Couldn't sign in with Apple. Please try again, or use your phone or email instead.",
      );
    } catch (e) {
      // Raw platform errors mean nothing to a customer — log, show a sentence.
      if (kDebugMode) debugPrint('[apple] sign-in failed: $e');
      throw const AppleSignInFailure(
        "Couldn't sign in with Apple. Please try again, or use your phone or email instead.",
      );
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AppleSignInFailure(
        'Apple did not return a sign-in token. Please try again.',
      );
    }
    return AppleCredential(
      idToken: idToken,
      rawNonce: rawNonce,
      fullName: appleFullName(credential.givenName, credential.familyName),
    );
  }
}

final appleSignInServiceProvider =
    Provider<AppleSignInService>((ref) => AppleSignInService());
