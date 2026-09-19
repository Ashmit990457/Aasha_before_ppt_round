package com.aasha.web.dto;

import com.aasha.web.entity.Alert;
import com.aasha.web.util.SeverityZoneConfig;
import java.time.LocalDateTime;

public record AlertResponse(
        Long id,
        String incidentId,
        String title,
        String message,
        String type,
        String severity,
        String district,
        String state,
        Double latitude,
        Double longitude,
        Double radiusKm,
        boolean active,
        LocalDateTime createdAt,
        double redZoneKm,
        double yellowZoneKm,
        double greenZoneKm
) {
    public static AlertResponse from(Alert alert) {
        return from(alert, alert.getSeverity());
    }

    public static AlertResponse from(Alert alert, String severity) {
        var zoneRadii = SeverityZoneConfig.getZoneRadii(severity);
        return new AlertResponse(
                alert.getId(), alert.getIncidentId(), alert.getTitle(), alert.getMessage(), alert.getType(),
                alert.getSeverity(), alert.getDistrict(), alert.getState(),
                alert.getLatitude(), alert.getLongitude(), alert.getRadiusKm(),
                alert.isActive(), alert.getCreatedAt(),
                zoneRadii.redKm(), zoneRadii.yellowKm(), zoneRadii.greenKm()
        );
    }
}
