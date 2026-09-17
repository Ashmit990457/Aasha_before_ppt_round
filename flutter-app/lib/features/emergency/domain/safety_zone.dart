enum SafetyZone { safe, green, yellow, red, unknown }

class SafetyResult {
  final SafetyZone zone;
  final double? distanceFromDisasterKm;
  final double? radiusKm;
  final double? percentageOfRadius;

  const SafetyResult({
    required this.zone,
    this.distanceFromDisasterKm,
    this.radiusKm,
    this.percentageOfRadius,
  });
}
