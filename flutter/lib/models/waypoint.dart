class Waypoint {
  final String id;
  final double latitude;
  final double longitude;
  final String label;
  final bool snapAfter;

  const Waypoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.snapAfter,
  });

  Waypoint copyWith({
    double? latitude,
    double? longitude,
    String? label,
    bool? snapAfter,
  }) {
    return Waypoint(
      id: id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      snapAfter: snapAfter ?? this.snapAfter,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'snapAfter': snapAfter,
      };

  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
        id: json['id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        label: json['label'] as String,
        snapAfter: json['snapAfter'] as bool? ?? true,
      );
}
