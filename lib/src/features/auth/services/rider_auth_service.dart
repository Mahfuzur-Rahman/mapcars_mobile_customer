import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../demo_credentials.dart';
import '../models/auth_state.dart';

/// Result from `GET/PATCH /me` — the rider's full profile, richer than
/// [AuthResult] (which is shared with login/signup).
class RiderProfile {
  const RiderProfile({
    required this.riderId,
    this.fullName,
    this.email,
    this.phone,
    this.emergencyContactName,
    this.emergencyContactPhone,
    required this.marketingConsent,
    this.accessibilityNeeds,
    this.hasProfilePicture = false,
    required this.isProfileComplete,
  });

  final String riderId;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool marketingConsent;
  final String? accessibilityNeeds;
  final bool hasProfilePicture;
  final bool isProfileComplete;

  factory RiderProfile.fromJson(Map<String, dynamic> j) => RiderProfile(
        riderId: j['riderId'].toString(),
        fullName: j['fullName'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        emergencyContactName: j['emergencyContactName'] as String?,
        emergencyContactPhone: j['emergencyContactPhone'] as String?,
        marketingConsent: j['marketingConsent'] as bool? ?? false,
        accessibilityNeeds: j['accessibilityNeeds'] as String?,
        hasProfilePicture: j['hasProfilePicture'] as bool? ?? false,
        isProfileComplete: j['isProfileComplete'] as bool? ?? false,
      );
}

/// Result from send-OTP — wraps the API's OtpSentResponse.
class OtpSentResult {
  const OtpSentResult({required this.message, this.devCode});
  final String message;
  final String? devCode;
}

/// Result from any auth flow that returns a token.
class AuthResult {
  const AuthResult({
    required this.token,
    this.refreshToken,
    required this.expiresInMinutes,
    required this.userId,
    this.fullName,
    this.email,
    this.phone,
    required this.isProfileComplete,
    required this.isEmailVerified,
    required this.isPhoneVerified,
  });

  final String token;

  /// Long-lived credential for `POST /api/v1/auth/refresh`. Absent only if the
  /// API predates refresh tokens.
  final String? refreshToken;

  final int expiresInMinutes;
  final String userId;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool isProfileComplete;
  final bool isEmailVerified;
  final bool isPhoneVerified;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: j['token'] as String,
        refreshToken: j['refreshToken'] as String?,
        expiresInMinutes: j['expiresInMinutes'] as int? ?? 60,
        userId: j['userId'] as String,
        fullName: j['fullName'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        isProfileComplete: j['isProfileComplete'] as bool? ?? false,
        isEmailVerified: j['isEmailVerified'] as bool? ?? false,
        isPhoneVerified: j['isPhoneVerified'] as bool? ?? false,
      );

  AuthState toAuthState() => AuthState(
        token: token,
        refreshToken: refreshToken,
        userId: userId,
        fullName: fullName,
        email: email,
        phone: phone,
        isProfileComplete: isProfileComplete,
        isEmailVerified: isEmailVerified,
        isPhoneVerified: isPhoneVerified,
      );

  /// A synthetic result for the offline demo account (no API call). See
  /// [DemoCredentials] — used while the backend is not reachable.
  factory AuthResult.demo() => const AuthResult(
        token: DemoCredentials.token,
        expiresInMinutes: DemoCredentials.sessionMinutes,
        userId: DemoCredentials.userId,
        fullName: DemoCredentials.fullName,
        email: DemoCredentials.email,
        phone: DemoCredentials.phone,
        isProfileComplete: true,
        isEmailVerified: true,
        isPhoneVerified: true,
      );
}

class RiderAuthService {
  RiderAuthService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/auth/riders';

  /// Revokes this device's refresh token server-side. Shared across roles, so it
  /// lives at `/api/v1/auth/logout` rather than under the per-role base above.
  ///
  /// Always succeeds from the caller's point of view: the API answers 204 even
  /// for a token it has never seen, because signing out twice is not an error.
  Future<void> logout(String refreshToken) => apiCall(() async {
        await _dio.post<void>(
          '/api/v1/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      });

  Future<OtpSentResult> sendPhoneOtp(String phone) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/send-otp',
          data: {'phone': phone},
        );
        final d = res.data!;
        return OtpSentResult(
          message: d['message'] as String? ?? 'OTP sent.',
          devCode: d['devCode'] as String?,
        );
      });

  Future<AuthResult> verifyPhoneOtp(String phone, String code) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/verify-phone',
          data: {'phone': phone, 'code': code},
        );
        return AuthResult.fromJson(res.data!);
      });

  Future<OtpSentResult> signUpWithEmail(
          String email, String password, String fullName) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/signup',
          data: {'email': email, 'password': password, 'fullName': fullName},
        );
        final d = res.data!;
        return OtpSentResult(
          message: d['message'] as String? ?? 'OTP sent.',
          devCode: d['devCode'] as String?,
        );
      });

  Future<OtpSentResult> resendEmailOtp(String email) => apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/resend-email',
          data: {'email': email},
        );
        final d = res.data!;
        return OtpSentResult(
          message: d['message'] as String? ?? 'Code resent.',
          devCode: d['devCode'] as String?,
        );
      });

  Future<AuthResult> verifyEmailOtp(String email, String code) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/verify-email',
          data: {'email': email, 'code': code},
        );
        return AuthResult.fromJson(res.data!);
      });

  Future<AuthResult> loginWithEmail(String email, String password) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/login',
          data: {'email': email, 'password': password},
        );
        return AuthResult.fromJson(res.data!);
      });

  /// `signUp` must only be true from a sign-up surface. From a sign-in screen
  /// it stays false, so the API refuses to invent an account for a Google
  /// address that has never signed up.
  Future<AuthResult> signInWithGoogle(String idToken, {bool signUp = false}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/google',
          data: {'idToken': idToken, 'signUp': signUp},
        );
        return AuthResult.fromJson(res.data!);
      });

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<RiderProfile> getProfile() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/me');
        return RiderProfile.fromJson(res.data!);
      });

  Future<RiderProfile> updateProfile({
    required String fullName,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? marketingConsent,
    String? accessibilityNeeds,
  }) =>
      apiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '$_base/me',
          data: {
            'fullName': fullName,
            if (email != null && email.isNotEmpty) 'email': email,
            if (emergencyContactName != null)
              'emergencyContactName': emergencyContactName,
            if (emergencyContactPhone != null)
              'emergencyContactPhone': emergencyContactPhone,
            if (marketingConsent != null) 'marketingConsent': marketingConsent,
            if (accessibilityNeeds != null)
              'accessibilityNeeds': accessibilityNeeds,
          },
        );
        return RiderProfile.fromJson(res.data!);
      });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      apiCall(() async {
        await _dio.post<void>(
          '$_base/me/change-password',
          data: {
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          },
        );
      });

  Future<RiderProfile> uploadProfilePicture(File file) => apiCall(() async {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path),
        });
        final res = await _dio.put<Map<String, dynamic>>(
          '$_base/me/picture',
          data: formData,
        );
        return RiderProfile.fromJson(res.data!);
      });

  /// URL to fetch the rider's profile picture. Pass with an `Authorization`
  /// header (see `Image.network(..., headers: ...)`).
  String profilePictureUrl(String baseUrl) => '$baseUrl$_base/me/picture';
}

final riderAuthServiceProvider = Provider<RiderAuthService>(
  (ref) => RiderAuthService(ref.watch(dioProvider)),
);
