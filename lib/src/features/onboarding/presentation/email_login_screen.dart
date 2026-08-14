import 'package:flutter/material.dart';

import 'phone_screen.dart';

/// Email login route wrapper for customer_app — delegates to the unified
/// single-page login screen with the Email & Password tab pre-selected.
class EmailLoginScreen extends StatelessWidget {
  const EmailLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhoneScreen(initialTab: AuthTab.email);
  }
}
