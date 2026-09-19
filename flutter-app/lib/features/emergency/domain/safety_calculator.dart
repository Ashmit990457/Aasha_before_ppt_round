import 'dart:math' as math;

import 'safety_zone.dart';

class SafetyCalculator {
  static const double redThreshold = 0.30;
  static const double yellowThreshold = 0.70;
  static const double earthRadiusKm = 6371.0;

  static SafetyResult classify({
    required double userLatitude,
    required double userLongitude,
    required double disasterLatitude,
    required double disasterLongitude,
    required double radiusKm,
  }) {
    if (!_validCoordinate(userLatitude, userLongitude) ||
        !_validCoordinate(disasterLatitude, disasterLongitude) ||
        !radiusKm.isFinite ||
        radiusKm <= 0) {
      return const SafetyResult(zone: SafetyZone.unknown);
    }

    final distanceKm = distanceKmBetween(
      userLatitude,
      userLongitude,
      disasterLatitude,
      disasterLongitude,
    );
    final percentage = distanceKm / radiusKm;
    final zone = percentage <= redThreshold
        ? SafetyZone.red
        : percentage <= yellowThreshold
        ? SafetyZone.yellow
        : percentage <= 1
        ? SafetyZone.green
        : SafetyZone.safe;

    return SafetyResult(
      zone: zone,
      distanceFromDisasterKm: distanceKm,
      radiusKm: radiusKm,
      percentageOfRadius: percentage,
    );
  }

  static SafetyResult classifyWithFixedZones({
    required double userLatitude,
    required double userLongitude,
    required double disasterLatitude,
    required double disasterLongitude,
    required double redZoneKm,
    required double yellowZoneKm,
    required double greenZoneKm,
  }) {
    if (!_validCoordinate(userLatitude, userLongitude) ||
        !_validCoordinate(disasterLatitude, disasterLongitude) ||
        !redZoneKm.isFinite ||
        redZoneKm <= 0 ||
        !yellowZoneKm.isFinite ||
        yellowZoneKm <= 0 ||
        !greenZoneKm.isFinite ||
        greenZoneKm <= 0) {
      return const SafetyResult(zone: SafetyZone.unknown);
    }

    final distanceKm = distanceKmBetween(
      userLatitude,
      userLongitude,
      disasterLatitude,
      disasterLongitude,
    );

    final zone = distanceKm <= redZoneKm
        ? SafetyZone.red
        : distanceKm <= yellowZoneKm
        ? SafetyZone.yellow
        : distanceKm <= greenZoneKm
        ? SafetyZone.green
        : SafetyZone.safe;

    return SafetyResult(
      zone: zone,
      distanceFromDisasterKm: distanceKm,
      radiusKm: greenZoneKm,
      percentageOfRadius: distanceKm / greenZoneKm,
    );
  }

  static double distanceKmBetween(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    if (!_validCoordinate(firstLatitude, firstLongitude) ||
        !_validCoordinate(secondLatitude, secondLongitude)) {
      return double.nan;
    }

    final latitudeDelta = _radians(secondLatitude - firstLatitude);
    final longitudeDelta = _radians(secondLongitude - firstLongitude);
    final firstLatitudeRadians = _radians(firstLatitude);
    final secondLatitudeRadians = _radians(secondLatitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(firstLatitudeRadians) *
            math.cos(secondLatitudeRadians) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final centralAngle = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * centralAngle;
  }

  static bool _validCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
