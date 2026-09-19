class Incident {
  const Incident({
    required this.id,
    required this.name,
    this.description,
    this.active = true,
    this.searchable = true,
    this.district,
    this.state,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.severity,
    this.redZoneKm,
    this.yellowZoneKm,
    this.greenZoneKm,
  });

  final String id;
  final String name;
  final String? description;
  final bool active;
  final bool searchable;
  final String? district;
  final String? state;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final String? severity;
  final double? redZoneKm;
  final double? yellowZoneKm;
  final double? greenZoneKm;

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: json['description'] as String?,
        active: json['active'] != false,
        searchable: json['searchable'] != false,
        district: json['district'] as String?,
        state: json['state'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        radiusKm: (json['radiusKm'] ?? json['radius_km'] as num?)?.toDouble(),
        severity: json['severity'] as String?,
        redZoneKm: (json['redZoneKm'] ?? json['red_zone_km'] as num?)?.toDouble(),
        yellowZoneKm: (json['yellowZoneKm'] ?? json['yellow_zone_km'] as num?)?.toDouble(),
        greenZoneKm: (json['greenZoneKm'] ?? json['green_zone_km'] as num?)?.toDouble(),
      );
}
