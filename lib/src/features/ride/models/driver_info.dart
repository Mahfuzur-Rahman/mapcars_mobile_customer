/// The assigned driver shown on the tracking / in-progress screens.
class DriverInfo {
  const DriverInfo({
    required this.name,
    required this.rating,
    required this.vehicle,
    required this.plate,
    this.phone,
  });

  final String name; // 'James K.'
  final double rating; // 4.9
  final String vehicle; // 'Silver Toyota Prius · Economy'
  final String plate; // 'LB12 KXR'
  final String? phone;

  factory DriverInfo.fromJson(Map<String, dynamic> j) => DriverInfo(
        name: (j['name'] ?? '') as String,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        vehicle: (j['vehicle'] ?? '') as String,
        plate: (j['plate'] ?? '') as String,
        phone: j['phone'] as String?,
      );
}
