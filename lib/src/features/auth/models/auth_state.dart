import 'auth_session.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.token,
    this.refreshToken,
    this.expiresAt,
    this.userId,
    this.fullName,
    this.email,
    this.phone,
    this.isProfileComplete = false,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.error,
    this.pendingPhone,
    this.devOtpCode,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.marketingConsent = false,
    this.accessibilityNeeds,
    this.hasProfilePicture = false,
  });

  final bool isLoading;
  final String? token;

  /// Long-lived credential used to renew [token] silently. Its presence is what
  /// separates "expired, renew it" from "genuinely signed out".
  final String? refreshToken;

  /// When the current token expires. Used to drop stale sessions on restore.
  final DateTime? expiresAt;
  final String? userId;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool isProfileComplete;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String? error;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool marketingConsent;
  final String? accessibilityNeeds;
  final bool hasProfilePicture;

  /// Phone number stored between send-OTP and verify-OTP steps.
  final String? pendingPhone;

  /// Returned by the API in dev mode — displayed on-screen so you can type it.
  final String? devOtpCode;

  bool get isAuthenticated => token != null && !isExpired;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// The persistable slice of this state, or null if not authenticated.
  AuthSession? toSession() {
    final t = token;
    final uid = userId;
    final exp = expiresAt;
    if (t == null || uid == null || exp == null) return null;
    return AuthSession(
      token: t,
      refreshToken: refreshToken,
      expiresAt: exp,
      userId: uid,
      fullName: fullName,
      email: email,
      phone: phone,
      isProfileComplete: isProfileComplete,
      isEmailVerified: isEmailVerified,
      isPhoneVerified: isPhoneVerified,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      marketingConsent: marketingConsent,
      accessibilityNeeds: accessibilityNeeds,
      hasProfilePicture: hasProfilePicture,
    );
  }

  factory AuthState.fromSession(AuthSession s) => AuthState(
        token: s.token,
        refreshToken: s.refreshToken,
        expiresAt: s.expiresAt,
        userId: s.userId,
        fullName: s.fullName,
        email: s.email,
        phone: s.phone,
        isProfileComplete: s.isProfileComplete,
        isEmailVerified: s.isEmailVerified,
        isPhoneVerified: s.isPhoneVerified,
        emergencyContactName: s.emergencyContactName,
        emergencyContactPhone: s.emergencyContactPhone,
        marketingConsent: s.marketingConsent,
        accessibilityNeeds: s.accessibilityNeeds,
        hasProfilePicture: s.hasProfilePicture,
      );

  AuthState copyWith({
    bool? isLoading,
    String? token,
    String? refreshToken,
    DateTime? expiresAt,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    bool? isProfileComplete,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    String? error,
    String? pendingPhone,
    String? devOtpCode,
    bool clearError = false,
    bool clearDevOtp = false,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? marketingConsent,
    String? accessibilityNeeds,
    bool? hasProfilePicture,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        token: token ?? this.token,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        userId: userId ?? this.userId,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        isProfileComplete: isProfileComplete ?? this.isProfileComplete,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
        error: clearError ? null : (error ?? this.error),
        pendingPhone: pendingPhone ?? this.pendingPhone,
        devOtpCode: clearDevOtp ? null : (devOtpCode ?? this.devOtpCode),
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
        marketingConsent: marketingConsent ?? this.marketingConsent,
        accessibilityNeeds: accessibilityNeeds ?? this.accessibilityNeeds,
        hasProfilePicture: hasProfilePicture ?? this.hasProfilePicture,
      );
}
