package com.aasha.web.dto;

import com.aasha.web.entity.Incident;
import com.aasha.web.util.SeverityZoneConfig;
import java.time.LocalDateTime;

public record IncidentResponse(
        String id,
        String name,
        String description,
        boolean active,
        boolean searchable,
        String district,
        String state,
        Double latitude,
        Double longitude,
        Double radiusKm,
        String severity,
        LocalDateTime createdAt,
        double redZoneKm,
        double yellowZoneKm,
        double greenZoneKm
) {
    public static IncidentResponse from(Incident incident) {
        var zoneRadii = SeverityZoneConfig.getZoneRadii(incident.getSeverity());
        return new IncidentResponse(incident.getId(), incident.getName(), incident.getDescription(),
                incident.isActive(), incident.isSearchable(), incident.getDistrict(), incident.getState(),
                incident.getLatitude(), incident.getLongitude(), incident.getRadiusKm(), incident.getSeverity(),
                incident.getCreatedAt(), zoneRadii.redKm(), zoneRadii.yellowKm(), zoneRadii.greenKm());
    }
}
