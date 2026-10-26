import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/router/app_router.dart';

void main() {
  String? redirect(String path, {bool loggedIn = true, bool complete = true}) =>
      authRedirect(path: path, loggedIn: loggedIn, profileComplete: complete, isDev: false);

  test('a brand-new sign-up on a sign-in screen goes to profile setup, not home', () {
    for (final path in ['/otp', '/phone', '/email-login', '/email-signup', '/verify-email']) {
      expect(redirect(path, complete: false), '/profile-setup', reason: path);
    }
  });

  test('a complete profile on a sign-in screen goes home', () {
    expect(redirect('/otp'), '/home');
  });

  test('signed out on a private screen goes to intro; public screens stay', () {
    expect(redirect('/home', loggedIn: false), '/intro');
    expect(redirect('/otp', loggedIn: false), isNull);
  });

  test('profile setup itself is not redirected', () {
    expect(redirect('/profile-setup', complete: false), isNull);
  });
}
