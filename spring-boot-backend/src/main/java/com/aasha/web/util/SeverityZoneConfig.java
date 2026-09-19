package com.aasha.web.util;

public final class SeverityZoneConfig {

    private SeverityZoneConfig() {}

    public static final double MODERATE_RED_KM = 1.0;
    public static final double MODERATE_YELLOW_KM = 3.0;
    public static final double MODERATE_GREEN_KM = 5.0;

    public static final double SEVERE_RED_KM = 2.0;
    public static final double SEVERE_YELLOW_KM = 5.0;
    public static final double SEVERE_GREEN_KM = 10.0;

    public static final double CRITICAL_RED_KM = 3.0;
    public static final double CRITICAL_YELLOW_KM = 7.0;
    public static final double CRITICAL_GREEN_KM = 15.0;

    public record ZoneRadii(double redKm, double yellowKm, double greenKm) {}

    public static ZoneRadii getZoneRadii(String severity) {
        if (severity == null) {
            return new ZoneRadii(MODERATE_RED_KM, MODERATE_YELLOW_KM, MODERATE_GREEN_KM);
        }
        return switch (severity.toUpperCase()) {
            case "MODERATE" -> new ZoneRadii(MODERATE_RED_KM, MODERATE_YELLOW_KM, MODERATE_GREEN_KM);
            case "SEVERE" -> new ZoneRadii(SEVERE_RED_KM, SEVERE_YELLOW_KM, SEVERE_GREEN_KM);
            case "CRITICAL" -> new ZoneRadii(CRITICAL_RED_KM, CRITICAL_YELLOW_KM, CRITICAL_GREEN_KM);
            default -> new ZoneRadii(MODERATE_RED_KM, MODERATE_YELLOW_KM, MODERATE_GREEN_KM);
        };
    }

    public static double getRedKm(String severity) {
        return getZoneRadii(severity).redKm();
    }

    public static double getYellowKm(String severity) {
        return getZoneRadii(severity).yellowKm();
    }

    public static double getGreenKm(String severity) {
        return getZoneRadii(severity).greenKm();
    }
}