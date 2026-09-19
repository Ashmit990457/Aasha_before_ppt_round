import 'emergency_alert.dart';

class DisasterZone {
  final String id;
  final String? incidentId;
  final String disasterType;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final EmergencySeverity severity;
  final String title;
  final bool active;
  final double redZoneKm;
  final double yellowZoneKm;
  final double greenZoneKm;

  const DisasterZone({
    required this.id,
    this.incidentId,
    required this.disasterType,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.severity,
    required this.title,
    this.active = true,
    required this.redZoneKm,
    required this.yellowZoneKm,
    required this.greenZoneKm,
  });
}
