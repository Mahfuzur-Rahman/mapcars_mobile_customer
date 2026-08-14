/// The pricing configuration served by the API (`GET /api/v1/fare-chart`).
///
/// Mirrors the backend `FareChart` (api/src/Mapcars.Application/Pricing/Models).
/// The app caches this and computes an instant local estimate with
/// [FareCalculator]; the API recomputes the fare authoritatively at booking from
/// the same chart, so what the rider sees matches what they're charged.
///
/// All money is integer **pence** (exact, no floating-point drift).
library;

class FareChart {
  const FareChart({
    required this.version,
    required this.currency,
    required this.base,
    required this.rates,
    required this.tiers,
    required this.modifiers,
    required this.platform,
  });

  final int version;
  final String currency;
  final FareBase base;
  final FareRates rates;
  final List<FareTier> tiers;
  final FareModifiers modifiers;
  final PlatformConfig platform;

  factory FareChart.fromJson(Map<String, dynamic> j) => FareChart(
        version: (j['version'] as num?)?.toInt() ?? 0,
        currency: (j['currency'] ?? 'GBP') as String,
        base: FareBase.fromJson(_map(j['base'])),
        rates: FareRates.fromJson(_map(j['rates'])),
        tiers: ((j['tiers'] as List?) ?? const [])
            .map((e) => FareTier.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        modifiers: FareModifiers.fromJson(_map(j['modifiers'])),
        platform: PlatformConfig.fromJson(_map(j['platform'])),
      );

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map<String, dynamic> ? v : const {};
}

class FareBase {
  const FareBase({required this.bookingFeePence, required this.minimumFarePence});
  final int bookingFeePence;
  final int minimumFarePence;

  factory FareBase.fromJson(Map<String, dynamic> j) => FareBase(
        bookingFeePence: (j['bookingFeePence'] as num?)?.toInt() ?? 0,
        minimumFarePence: (j['minimumFarePence'] as num?)?.toInt() ?? 0,
      );
}

class FareRates {
  const FareRates({required this.perMilePence, required this.perMinutePence});
  final int perMilePence;
  final int perMinutePence;

  factory FareRates.fromJson(Map<String, dynamic> j) => FareRates(
        perMilePence: (j['perMilePence'] as num?)?.toInt() ?? 0,
        perMinutePence: (j['perMinutePence'] as num?)?.toInt() ?? 0,
      );
}

class FareTier {
  const FareTier({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.baseFarePence,
    required this.multiplier,
    required this.capacity,
    required this.etaMinutes,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int baseFarePence;
  final double multiplier;
  final int capacity;
  final int etaMinutes;

  factory FareTier.fromJson(Map<String, dynamic> j) => FareTier(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        icon: (j['icon'] ?? 'car') as String,
        baseFarePence: (j['baseFarePence'] as num?)?.toInt() ?? 0,
        multiplier: (j['multiplier'] as num?)?.toDouble() ?? 1.0,
        capacity: (j['capacity'] as num?)?.toInt() ?? 4,
        etaMinutes: (j['etaMinutes'] as num?)?.toInt() ?? 0,
      );
}

class FareModifiers {
  const FareModifiers({
    required this.rushHour,
    required this.zones,
    required this.busyAreas,
    this.outsideCity,
  });

  final List<RushHourRule> rushHour;
  final List<ZoneSurcharge> zones;
  final List<BusyArea> busyAreas;
  final OutsideCityRule? outsideCity;

  factory FareModifiers.fromJson(Map<String, dynamic> j) => FareModifiers(
        rushHour: ((j['rushHour'] as List?) ?? const [])
            .map((e) => RushHourRule.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        zones: ((j['zones'] as List?) ?? const [])
            .map((e) => ZoneSurcharge.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        busyAreas: ((j['busyAreas'] as List?) ?? const [])
            .map((e) => BusyArea.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        outsideCity: j['outsideCity'] is Map<String, dynamic>
            ? OutsideCityRule.fromJson(j['outsideCity'] as Map<String, dynamic>)
            : null,
      );
}

class RushHourRule {
  const RushHourRule({
    required this.days,
    required this.from,
    required this.to,
    required this.multiplier,
  });

  final List<int> days; // ISO: 1=Mon .. 7=Sun; empty = every day
  final String from; // "HH:mm"
  final String to;
  final double multiplier;

  factory RushHourRule.fromJson(Map<String, dynamic> j) => RushHourRule(
        days: ((j['days'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(growable: false),
        from: (j['from'] ?? '00:00') as String,
        to: (j['to'] ?? '00:00') as String,
        multiplier: (j['multiplier'] as num?)?.toDouble() ?? 1.0,
      );
}

class ZoneSurcharge {
  const ZoneSurcharge({
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.surchargePence,
    required this.appliesToPickup,
    required this.appliesToDropoff,
  });

  final double lat;
  final double lng;
  final int radiusM;
  final int surchargePence;
  final bool appliesToPickup;
  final bool appliesToDropoff;

  factory ZoneSurcharge.fromJson(Map<String, dynamic> j) => ZoneSurcharge(
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        radiusM: (j['radiusM'] as num?)?.toInt() ?? 0,
        surchargePence: (j['surchargePence'] as num?)?.toInt() ?? 0,
        appliesToPickup: (j['appliesToPickup'] as bool?) ?? true,
        appliesToDropoff: (j['appliesToDropoff'] as bool?) ?? true,
      );
}

class BusyArea {
  const BusyArea({
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.multiplier,
  });

  final double lat;
  final double lng;
  final int radiusM;
  final double multiplier;

  factory BusyArea.fromJson(Map<String, dynamic> j) => BusyArea(
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        radiusM: (j['radiusM'] as num?)?.toInt() ?? 0,
        multiplier: (j['multiplier'] as num?)?.toDouble() ?? 1.0,
      );
}

class OutsideCityRule {
  const OutsideCityRule({
    required this.cityLat,
    required this.cityLng,
    required this.radiusM,
    required this.multiplier,
  });

  final double cityLat;
  final double cityLng;
  final int radiusM;
  final double multiplier;

  factory OutsideCityRule.fromJson(Map<String, dynamic> j) => OutsideCityRule(
        cityLat: (j['cityLat'] as num?)?.toDouble() ?? 0,
        cityLng: (j['cityLng'] as num?)?.toDouble() ?? 0,
        radiusM: (j['radiusM'] as num?)?.toInt() ?? 0,
        multiplier: (j['multiplier'] as num?)?.toDouble() ?? 1.0,
      );
}

class PlatformConfig {
  const PlatformConfig({required this.driverFeePercent});
  final double driverFeePercent;

  factory PlatformConfig.fromJson(Map<String, dynamic> j) => PlatformConfig(
        driverFeePercent: (j['driverFeePercent'] as num?)?.toDouble() ?? 0,
      );
}
