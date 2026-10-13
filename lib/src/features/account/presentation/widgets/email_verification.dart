import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/friendly_error.dart';
import '../../../../core/widgets/mc.dart';
import '../../../auth/providers/auth_notifier.dart';
import '../../../auth/services/customer_auth_service.dart';

/// Why a profile-email verification call failed, in words a customer can act
/// on. Rate limiting (429) gets its own sentence: the rate limiter answers with
/// an empty body, so the API has no wording of its own to pass through.
String profileEmailErrorMessage(Object error) {
  if (error is ApiException && error.statusCode == 429) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }
  return friendlyError(error);
}

/// Small "Verified" / "Unverified" status pill for the profile email.
///
/// Status only — not a control — so it carries no tap target of its own.
class EmailVerificationPill extends StatelessWidget {
  const EmailVerificationPill({super.key, required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final fg = verified ? Brand.successText : Brand.warnText;
    return Semantics(
      label: verified ? 'Email verified' : 'Email not verified',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: verified ? Brand.successBg : Brand.warnBg,
          borderRadius: BorderRadius.circular(99),
          border: verified ? null : Border.all(color: Brand.warnBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.error_outline_rounded,
              size: 13,
              color: fg,
            ),
            const SizedBox(width: 4),
            Text(verified ? 'Verified' : 'Unverified',
                style: tw(FontWeight.w800, 11.5, fg)),
          ],
        ),
      ),
    );
  }
}

/// Opens the code-entry sheet for the profile email. [sent] is the reply to the
/// send-code call the caller has already made (so a failure to send is shown
/// where the customer tapped, not in an empty sheet).
///
/// Resolves to true once the email is verified; the auth state has been
/// updated by then.
Future<bool> showVerifyEmailSheet(
  BuildContext context, {
  required OtpSentResult sent,
}) async {
  final verified = await showMcBottomSheet<bool>(
    context,
    builder: (_) => _VerifyEmailSheet(sent: sent),
  );
  return verified ?? false;
}

class _VerifyEmailSheet extends ConsumerStatefulWidget {
  const _VerifyEmailSheet({required this.sent});
  final OtpSentResult sent;

  @override
  ConsumerState<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends ConsumerState<_VerifyEmailSheet> {
  /// How long "Resend code" stays disabled after a code goes out.
  static const _resendCooldown = 30;

  late String _message = widget.sent.message;
  late String? _devCode = widget.sent.devCode;
  String _code = '';
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  int _resendIn = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _resendIn = _resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _confirm() async {
    if (_verifying) return;
    if (_code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).verifyProfileEmail(_code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = profileEmailErrorMessage(e);
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final sent =
          await ref.read(authNotifierProvider.notifier).sendProfileEmailCode();
      if (!mounted) return;
      setState(() {
        _resending = false;
        _message = sent.message;
        _devCode = sent.devCode;
        _startCooldown();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = profileEmailErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _resendIn <= 0 && !_resending && !_verifying;
    final resendLabel = _resending
        ? 'Sending…'
        : (_resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code');

    // Confirm is the footer, so it stays above the keyboard; the error rides
    // with it because it answers the tap on Confirm (or Resend).
    return McSheet(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            McNotice(McErrorBanner(_error!)),
            const SizedBox(height: 12),
          ],
          McButton(
            _verifying ? 'Verifying…' : 'Confirm',
            icon: _verifying ? null : 'check',
            onTap: _verifying ? null : _confirm,
          ),
          const SizedBox(height: 10),
          McGhostButton(
            resendLabel,
            icon: 'mail',
            height: 48,
            onTap: canResend ? _resend : null,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const McTitle('Verify your email', size: 20),
            const SizedBox(height: 6),
            Text(_message, style: tw(FontWeight.w600, 13.5, Brand.sub)),
            const SizedBox(height: 4),
            Text('Enter the 6-digit code to get trip receipts by email.',
                style: tw(FontWeight.w600, 13.5, Brand.sub)),
            const SizedBox(height: 18),
            OtpInput(
              length: 6,
              autofocus: true,
              onChanged: (v) => setState(() {
                _code = v;
                _error = null;
              }),
              onCompleted: (v) {
                _code = v;
                _confirm();
              },
            ),
            if (AppConfig.showDevOtp && _devCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Brand.warnBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Brand.warnBorder),
                ),
                child: Row(
                  children: [
                    const Ico('mail', size: 16, color: Brand.warnText),
                    const SizedBox(width: 8),
                    Text('Dev code: $_devCode',
                        style: tw(FontWeight.w700, 14, Brand.warnText)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
