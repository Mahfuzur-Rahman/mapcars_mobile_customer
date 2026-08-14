import 'dart:math' as math;

import '../models/fare_chart.dart';
import '../models/ride_option.dart';

/// On-device fare estimate. This is a faithful port of the backend
/// `FareCalculator` (api/src/Mapcars.Application/Pricing/FareCalculator.cs) so the
/// price shown here matches the API's authoritative recompute at booking.
///
/// Pure arithmetic on integer pence — cheap enough to run on every map change.
///
/// Formula, per tier:
///   subtotal = bookingFee + tier.baseFare + perMile*miles + perMinute*minutes
///   subtotal *= tier.multiplier
///   subtotal *= surge          (rushHour × busyArea × outsideCity)
///   subtotal += zoneSurcharges (airport/station flat add-ons)
///   fare = max(round(subtotal), minimumFare)
class FareCalculator {
  const FareCalculator._();

  /// Prices every tier in [chart] for a route, returning bookable [RideOption]s.
  static List<RideOption> options({
    required FareChart chart,
    required double miles,
    required double minutes,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    DateTime? now,
  }) {
    final localNow = now ?? DateTime.now();
    return chart.tiers
        .map((t) => _priceTier(
              chart, t, miles, minutes,
              pickupLat, pickupLng, dropoffLat, dropoffLng, localNow,
            ))
        .toList(growable: false);
  }

  static RideOption _priceTier(
    FareChart chart,
    FareTier tier,
    double miles,
    double minutes,
    double pickupLat,
    double pickupLng,
    double dropoffLat,
    double dropoffLng,
    DateTime localNow,
  ) {
    miles = math.max(0, miles);
    minutes = math.max(0, minutes);

    double subtotal = chart.base.bookingFeePence +
        tier.baseFarePence +
        chart.rates.perMilePence * miles +
        chart.rates.perMinutePence * minutes;

    subtotal *= tier.multiplier;
    subtotal *= _surge(chart, pickupLat, pickupLng, localNow);
    subtotal += _zoneSurchargePence(
        chart, pickupLat, pickupLng, dropoffLat, dropoffLng);

    final fare = math.max(subtotal.round(), chart.base.minimumFarePence);

    return RideOption(
      id: tier.id,
      tier: tier.id,
      name: tier.name,
      etaMinutes: tier.etaMinutes,
      pricePence: fare,
      description: tier.description,
      icon: tier.icon,
    );
  }

  static double _surge(FareChart chart, double lat, double lng, DateTime localNow) {
    double m = 1.0;

    for (final r in chart.modifiers.rushHour) {
      if (_matchesRushHour(r, localNow)) m *= r.multiplier;
    }

    for (final b in chart.modifiers.busyAreas) {
      if (_withinMeters(lat, lng, b.lat, b.lng, b.radiusM)) {
        m *= b.multiplier;
        break;
      }
    }

    final oc = chart.modifiers.outsideCity;
    if (oc != null && !_withinMeters(lat, lng, oc.cityLat, oc.cityLng, oc.radiusM)) {
      m *= oc.multiplier;
    }

    return m;
  }

  static int _zoneSurchargePence(
    FareChart chart,
    double pLat,
    double pLng,
    double dLat,
    double dLng,
  ) {
    int total = 0;
    for (final z in chart.modifiers.zones) {
      final hit = (z.appliesToPickup && _withinMeters(pLat, pLng, z.lat, z.lng, z.radiusM)) ||
          (z.appliesToDropoff && _withinMeters(dLat, dLng, z.lat, z.lng, z.radiusM));
      if (hit) total += z.surchargePence;
    }
    return total;
  }

  static bool _matchesRushHour(RushHourRule r, DateTime localNow) {
    // Dart weekday: Mon=1 .. Sun=7 (already ISO).
    if (r.days.isNotEmpty && !r.days.contains(localNow.weekday)) return false;

    final from = _parseMinutes(r.from);
    final to = _parseMinutes(r.to);
    if (from == null || to == null) return false;

    final t = localNow.hour * 60 + localNow.minute;
    return from <= to ? (t >= from && t < to) : (t >= from || t < to);
  }

  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static bool _withinMeters(
      double lat1, double lng1, double lat2, double lng2, int radiusM) {
    const metersPerDegLat = 111320.0;
    if ((lat1 - lat2).abs() * metersPerDegLat > radiusM + 50) return false;
    return haversineMeters(lat1, lng1, lat2, lng2) <= radiusM;
  }

  static double haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180, dl = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
