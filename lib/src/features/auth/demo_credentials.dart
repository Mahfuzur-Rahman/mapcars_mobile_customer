/// Hard-coded demo account so the app runs fully offline — no API / database
/// needed — until the real auth endpoints are wired up.
///
/// Enter [phoneDisplay] on the phone screen and [otp] on the OTP screen (both
/// are pre-filled / shown on-screen). The auth flow detects the demo number and
/// short-circuits to a local session instead of calling the API. Swap back to
/// the API path (see [AuthNotifier]) once the backend is reachable.
class DemoCredentials {
  const DemoCredentials._();

  /// Canonical E.164 form the app stores / compares against.
  static const phone = '+447700900000';

  /// What the user types after the +44 prefix.
  static const phoneDisplay = '7700 900000';

  /// The accepted demo verification code.
  static const otp = '000000';

  static const userId = 'demo-rider';
  static const fullName = 'Demo Rider';
  static const email = 'demo.rider@mapcars.co.uk';

  /// A long-lived fake token so the persisted session survives restarts.
  static const token = 'demo-token-rider';
  static const sessionMinutes = 60 * 24 * 30; // 30 days
}

/// True when [phone] (any spacing / hyphenation) is the demo number.
bool isDemoPhone(String phone) =>
    phone.replaceAll(' ', '').replaceAll('-', '') == DemoCredentials.phone;
