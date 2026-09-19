package com.aasha.web.service;

import com.aasha.web.dto.AlertRequest;
import com.aasha.web.dto.AlertResponse;
import com.aasha.web.entity.Alert;
import com.aasha.web.repository.AlertRepository;
import com.aasha.web.util.SeverityZoneConfig;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Comparator;

@Service
public class AlertService {
    private static final Logger log = LoggerFactory.getLogger(AlertService.class);
    private final AlertRepository repository;
    private final FcmNotificationService notifications;
    private final IncidentService incidents;

    public AlertService(AlertRepository repository, FcmNotificationService notifications,
                        IncidentService incidents) {
        this.repository = repository;
        this.notifications = notifications;
        this.incidents = incidents;
    }

    public List<AlertResponse> activeAlerts() {
        return repository.findByActiveTrueOrderByCreatedAtDesc()
                .stream().map(AlertResponse::from).toList();
    }

    public List<AlertResponse> allAlerts() {
        return repository.findAll().stream()
            .sorted(Comparator.comparing(Alert::getCreatedAt,
                Comparator.nullsLast(Comparator.reverseOrder())))
                .map(AlertResponse::from).toList();
    }

    public AlertResponse create(AlertRequest request) {
        return create(request, null);
    }

    public AlertResponse create(AlertRequest request, String creator) {
        validateLocation(request);
        Alert alert = new Alert();
        var incident = request.getIncidentId() == null || request.getIncidentId().isBlank()
                ? incidents.createFromAlert(request, creator)
                : incidents.requireExisting(request.getIncidentId());
        alert.setIncidentId(incident.getId());
        alert.setTitle(request.getTitle().trim());
        alert.setMessage(request.getMessage());
        alert.setType(request.getType().trim());
        alert.setSeverity(request.getSeverity().trim());
        alert.setDistrict(request.getDistrict());
        alert.setState(request.getState());
        alert.setLatitude(request.getLatitude());
        alert.setLongitude(request.getLongitude());
        alert.setActive(request.getActive() == null || request.getActive());
        return AlertResponse.from(repository.save(alert), incident.getSeverity());
    }

    public AlertResponse setActive(Long id, boolean active) {
        Alert alert = repository.findById(id)
                .orElseThrow(() -> new AlertNotFoundException(id));
        alert.setActive(active);
        var saved = repository.save(alert);
        if (active && notifications != null) notifications.dispatch(saved);
        log.info("[ALERT-DEBUG] alert_id={} action={} database_status={}",
                id, active ? "ACTIVATE" : "DEACTIVATE", active ? "ACTIVE" : "INACTIVE");
        return AlertResponse.from(saved, alert.getSeverity());
    }

    public AlertResponse update(Long id, AlertRequest request) {
        validateLocation(request);
        Alert alert = repository.findById(id)
                .orElseThrow(() -> new AlertNotFoundException(id));
        alert.setTitle(request.getTitle().trim());
        if (request.getIncidentId() != null && !request.getIncidentId().isBlank()) {
            alert.setIncidentId(incidents.requireExisting(request.getIncidentId()).getId());
        }
        alert.setMessage(request.getMessage());
        alert.setType(request.getType().trim());
        alert.setSeverity(request.getSeverity().trim());
        alert.setDistrict(request.getDistrict());
        alert.setState(request.getState());
        alert.setLatitude(request.getLatitude());
        alert.setLongitude(request.getLongitude());
        if (request.getActive() != null) alert.setActive(request.getActive());
        return AlertResponse.from(repository.save(alert), alert.getSeverity());
    }

    private void validateLocation(AlertRequest request) {
        Double latitude = request.getLatitude();
        Double longitude = request.getLongitude();
        if ((latitude == null) != (longitude == null)) {
            throw new IllegalArgumentException("latitude and longitude must be provided together");
        }
        if (latitude != null && (!Double.isFinite(latitude) || latitude < -90 || latitude > 90)) {
            throw new IllegalArgumentException("latitude must be between -90 and 90");
        }
        if (longitude != null && (!Double.isFinite(longitude) || longitude < -180 || longitude > 180)) {
            throw new IllegalArgumentException("longitude must be between -180 and 180");
        }
    }

    public static class AlertNotFoundException extends RuntimeException {
        public AlertNotFoundException(Long id) { super("Alert not found: " + id); }
    }
}
