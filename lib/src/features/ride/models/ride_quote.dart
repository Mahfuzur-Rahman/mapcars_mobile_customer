import 'ride_option.dart';

/// The result of pricing a route: trip distance/duration plus the list of
/// bookable [RideOption]s. Built on-device by `rideQuoteProvider` from the
/// fare chart — there is no per-route server round-trip.
class RideQuote {
  const RideQuote({
    required this.distanceMiles,
    required this.etaMinutes,
    required this.options,
  });

  final double distanceMiles;
  final int etaMinutes; // overall trip duration estimate
  final List<RideOption> options;

  /// e.g. "Arrives in ~12 min · 4.3 mi" (matches the choose-ride header).
  String get summary =>
      'Arrives in ~$etaMinutes min · ${distanceMiles.toStringAsFixed(1)} mi';
}
