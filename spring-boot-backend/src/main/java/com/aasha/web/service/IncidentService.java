package com.aasha.web.service;

import com.aasha.web.dto.AlertRequest;
import com.aasha.web.dto.IncidentResponse;
import com.aasha.web.entity.Incident;
import com.aasha.web.repository.IncidentRepository;
import com.aasha.web.util.SeverityZoneConfig;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.UUID;

@Service
public class IncidentService {
    private final IncidentRepository repository;

    public IncidentService(IncidentRepository repository) { this.repository = repository; }

    public List<IncidentResponse> activeSearchable() {
        return repository.findByActiveTrueAndSearchableTrueOrderByCreatedAtDesc()
                .stream().map(IncidentResponse::from).toList();
    }

    public Incident requireActiveSearchable(String id) {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("incident_id is required");
        return repository.findById(id.trim())
                .filter(value -> value.isActive() && value.isSearchable())
                .orElseThrow(() -> new IllegalArgumentException("incident_id is not active or searchable"));
    }

    public Incident createFromAlert(AlertRequest request, String creator) {
        Incident incident = new Incident();
        incident.setId(UUID.randomUUID().toString());
        incident.setName(request.getTitle().trim());
        incident.setDescription(request.getMessage());
        incident.setActive(true);
        incident.setSearchable(true);
        incident.setDistrict(request.getDistrict());
        incident.setState(request.getState());
        incident.setLatitude(request.getLatitude());
        incident.setLongitude(request.getLongitude());
        var zoneRadii = SeverityZoneConfig.getZoneRadii(request.getSeverity());
        incident.setRadiusKm(zoneRadii.greenKm());
        incident.setSeverity(request.getSeverity());
        incident.setCreatedBy(creator);
        return repository.save(incident);
    }

    public Incident requireExisting(String id) {
        return repository.findById(id.trim())
                .orElseThrow(() -> new IllegalArgumentException("Unknown incident_id"));
    }
}
