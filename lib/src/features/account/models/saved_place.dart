/// A rider's saved address — Home, Work, or a custom label. Mirrors
/// `Mapcars.Api`'s `/api/v1/saved-places` shape; follows the same manual
/// fromJson/toJson style as `ride/models/place.dart`.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  final String id;
  final String label; // 'Home', 'Work', or a custom name
  final String address;
  final double lat;
  final double lng;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
        id: j['id'].toString(),
        label: (j['label'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        createdAtUtc: j['createdAtUtc'] == null
            ? null
            : DateTime.parse(j['createdAtUtc'] as String),
        updatedAtUtc: j['updatedAtUtc'] == null
            ? null
            : DateTime.parse(j['updatedAtUtc'] as String),
      );
}
