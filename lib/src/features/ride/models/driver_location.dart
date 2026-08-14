/// Where the assigned driver is right now, as pushed over SignalR
/// (`driverLocation`) or fetched from `GET /trips/{id}/driver-location`.
///
/// Mirrors the API's `TripDriverLocationResponse`, minus the fields only the
/// REST shape carries — a realtime push is current by definition, so it arrives
/// without an age.
class DriverLocation {
  const DriverLocation({
    required this.lat,
    required this.lng,
    this.heading,
    this.ageSeconds = 0,
  });

  final double lat;
  final double lng;

  /// Compass bearing in degrees (0 = north). Null when the driver's device
  /// couldn't supply one — the map keeps the marker's last known rotation
  /// rather than snapping it back to north.
  final double? heading;

  /// How stale this fix is. Only ever non-zero on the REST seed; a driver whose
  /// app has stopped reporting shows as "last seen" rather than live.
  final int ageSeconds;

  /// Beyond a minute without a fix the dot is no longer where the car is.
  /// Matches the API's 60s GEO freshness window.
  bool get isStale => ageSeconds > 60;

  factory DriverLocation.fromJson(Map<String, dynamic> j) => DriverLocation(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        heading: (j['heading'] as num?)?.toDouble(),
        ageSeconds: (j['ageSeconds'] as num?)?.toInt() ?? 0,
      );
}
