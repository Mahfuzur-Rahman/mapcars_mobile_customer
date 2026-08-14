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
    this.completedAt,
    this.cancelledAt,
    this.cancelledReason,
    this.isNoShow,
    this.paymentMethod = 'Cash',
    this.paymentStatus = 'Pending',
    this.paidAt,
    this.tier,
    this.tipPence = 0,
    this.distanceMiles,
    this.durationMinutes,
  });

  final String id;
  final TripStatus status;
  final Place pickup;
  final Place dropoff;
  final DriverInfo? driver;
  final int? farePence; // null until completed
  final String? pin; // meet-up PIN, e.g. '4821'
  final DateTime? createdAt;
  final DateTime? completedAt; // completedAtUtc
  final DateTime? cancelledAt; // cancelledAtUtc
  final String? cancelledReason;
  final bool? isNoShow;

  /// Payment method ('Cash' | 'Card') and settlement state
  /// ('Pending' | 'Collected' | 'Failed'), as sent by the API.
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? paidAt; // paidAtUtc — set once collected/captured

  /// Pricing snapshot (for the history list + receipt breakdown).
  final String? tier; // 'economy' | 'comfort' | 'xl' | 'premium'
  final int tipPence; // rider tip, paid on top of the fare
  final double? distanceMiles;
  final double? durationMinutes;

  String? get formattedFare => farePence == null ? null : formatGbp(farePence!);

  /// Fare + tip, the amount actually paid. Null until the fare is set.
  int? get totalPence => farePence == null ? null : farePence! + tipPence;
  String? get formattedTotal => totalPence == null ? null : formatGbp(totalPence!);
  String? get formattedTip => tipPence > 0 ? formatGbp(tipPence) : null;

  bool get isCash => paymentMethod.toLowerCase() == 'cash';

  /// Human label for the chosen method (e.g. 'Cash').
  String get paymentMethodLabel => isCash ? 'Cash' : 'Card';

  bool get isPaid => paymentStatus.toLowerCase() == 'collected';

  /// Title-cased tier, e.g. 'Economy'. Empty when unknown.
  String get tierLabel => (tier == null || tier!.isEmpty)
      ? ''
      : tier![0].toUpperCase() + tier!.substring(1);

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
      // API sends `createdAtUtc`; tolerate a bare `createdAt` too.
      createdAt: (j['createdAtUtc'] ?? j['createdAt']) != null
          ? DateTime.tryParse((j['createdAtUtc'] ?? j['createdAt']).toString())
          : null,
      completedAt: j['completedAtUtc'] != null
          ? DateTime.tryParse(j['completedAtUtc'].toString())
          : null,
      cancelledAt: j['cancelledAtUtc'] != null
          ? DateTime.tryParse(j['cancelledAtUtc'].toString())
          : null,
      cancelledReason: j['cancelledReason'] as String?,
      isNoShow: j['isNoShow'] as bool?,
      paymentMethod: (j['paymentMethod'] ?? 'Cash').toString(),
      paymentStatus: (j['paymentStatus'] ?? 'Pending').toString(),
      paidAt: j['paidAtUtc'] != null
          ? DateTime.tryParse(j['paidAtUtc'].toString())
          : null,
      tier: j['tier'] as String?,
      tipPence: (((j['tipAmount'] as num?)?.toDouble() ?? 0) * 100).round(),
      distanceMiles: (j['distanceMiles'] as num?)?.toDouble(),
      durationMinutes: (j['durationMinutes'] as num?)?.toDouble(),
    );
  }
}
