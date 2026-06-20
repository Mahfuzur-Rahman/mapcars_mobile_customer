import '../../../core/utils/money.dart';
import 'driver_info.dart';
import 'place.dart';
import 'trip_status.dart';

/// A requested/active/completed trip. Mirrors the backend `Trip` entity plus
/// the rider-facing extras (assigned driver, meet-up PIN).
class Trip {
  const Trip({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    this.driver,
    this.farePence,
    this.pin,
    this.createdAt,
  });

  final String id;
  final TripStatus status;
  final Place pickup;
  final Place dropoff;
  final DriverInfo? driver;
  final int? farePence; // null until completed
  final String? pin; // meet-up PIN, e.g. '4821'
  final DateTime? createdAt;

  String? get formattedFare => farePence == null ? null : formatGbp(farePence!);

  /// Parses both nested ({pickup:{...}}) and the backend's flat
  /// (pickupAddress/pickupLat/pickupLng) shapes, so this DTO works whichever
  /// way the trips endpoint ends up serializing.
  factory Trip.fromJson(Map<String, dynamic> j) {
    Place place(String prefix, String? nestedKey) {
      final nested = nestedKey != null ? j[nestedKey] : null;
      if (nested is Map<String, dynamic>) return Place.fromJson(nested);
      return Place(
        label: (j['${prefix}Address'] ?? '') as String,
        address: (j['${prefix}Address'] ?? '') as String,
        lat: (j['${prefix}Lat'] as num?)?.toDouble() ?? 0,
        lng: (j['${prefix}Lng'] as num?)?.toDouble() ?? 0,
      );
    }

    final fare = j['fareAmount'] ?? j['farePence'];
    return Trip(
      id: (j['id'] ?? '').toString(),
      status: TripStatus.fromApi(j['status']),
      pickup: place('pickup', 'pickup'),
      dropoff: place('dropoff', 'dropoff'),
      driver: j['driver'] is Map<String, dynamic>
          ? DriverInfo.fromJson(j['driver'] as Map<String, dynamic>)
          : null,
      farePence: fare == null
          ? null
          : (j.containsKey('farePence')
              ? (fare as num).toInt()
              : ((fare as num) * 100).round()),
      pin: j['pin'] as String?,
      createdAt:
          j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
    );
  }
}
