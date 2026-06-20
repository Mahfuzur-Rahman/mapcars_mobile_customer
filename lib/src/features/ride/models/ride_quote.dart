import 'ride_option.dart';

/// The result of pricing a route: trip distance/duration plus the list of
/// bookable [RideOption]s. Returned by `RideRepository.quote`.
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

  factory RideQuote.fromJson(Map<String, dynamic> j) => RideQuote(
        distanceMiles: (j['distanceMiles'] as num?)?.toDouble() ?? 0,
        etaMinutes: (j['etaMinutes'] as num?)?.toInt() ?? 0,
        options: ((j['options'] as List?) ?? const [])
            .map((e) => RideOption.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}
