/// Which payment methods the platform currently accepts.
///
/// Published by an admin (`GET /api/v1/payment-settings`, public, like the fare
/// chart) so cash can be switched off — or card switched on — without an app
/// release. The booking sheet renders from this rather than from a hard-coded
/// pair of buttons.
class PaymentSettings {
  const PaymentSettings({
    required this.cashEnabled,
    required this.cardEnabled,
    required this.defaultMethod,
  });

  final bool cashEnabled;
  final bool cardEnabled;

  /// `'cash'` or `'card'` — lowercased here because that is what the booking
  /// flow already passes to `requestTrip`. The API sends it capitalised.
  final String defaultMethod;

  /// What to fall back to when the settings call fails.
  ///
  /// Cash-only, deliberately. If we cannot reach the API we do not know whether
  /// card is switched on, and offering a method that turns out to be disabled
  /// produces a booking the server rejects. Offering cash when cash happens to be
  /// off is the milder failure — the server rejects it with a message, rather
  /// than the customer being charged in a way nobody intended.
  static const fallback =
      PaymentSettings(cashEnabled: true, cardEnabled: false, defaultMethod: 'cash');

  factory PaymentSettings.fromJson(Map<String, dynamic> j) => PaymentSettings(
        cashEnabled: j['cashEnabled'] as bool? ?? true,
        cardEnabled: j['cardEnabled'] as bool? ?? false,
        defaultMethod: (j['defaultMethod'] as String? ?? 'Cash').toLowerCase(),
      );

  /// The methods to actually offer, in display order.
  ///
  /// Never empty: the API refuses to disable both, but a client that trusted
  /// that and got it wrong would render a booking sheet with no way to pay.
  List<String> get available => [
        if (cashEnabled) 'cash',
        if (cardEnabled) 'card',
        if (!cashEnabled && !cardEnabled) 'cash',
      ];

  /// The method to preselect — the admin's default when it is actually
  /// offerable, otherwise whatever is.
  String get preselected =>
      available.contains(defaultMethod) ? defaultMethod : available.first;

  /// True when there is nothing to choose between, so the chooser should be a
  /// line of text rather than a row of one button.
  bool get hasChoice => available.length > 1;
}
