import '../../../core/utils/money.dart';

/// One bookable tier returned in a [RideQuote] for a given route — e.g.
/// Economy / Comfort / XL / Premium, each with its own ETA and price.
class RideOption {
  const RideOption({
    required this.id,
    required this.tier,
    required this.name,
    required this.etaMinutes,
    required this.pricePence,
    required this.description,
    required this.icon,
  });

  final String id; // server id used when requesting the trip
  final String tier; // 'economy' | 'comfort' | 'xl' | 'premium'
  final String name; // 'Economy'
  final int etaMinutes; // pickup ETA
  final int pricePence; // fare in pence (integer money)
  final String description; // 'Everyday rides'
  final String icon; // mc Ico name: 'car' | 'bolt'

  String get formattedEta => '$etaMinutes min away';
  String get formattedPrice => formatGbp(pricePence);
}
