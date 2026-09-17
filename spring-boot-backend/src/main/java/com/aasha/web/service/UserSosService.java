package com.aasha.web.service;

import com.aasha.web.dto.SosRequest;
import com.aasha.web.dto.SosResponse;
import com.aasha.web.dto.SosStatusRequest;
import com.aasha.web.entity.UserSos;
import com.aasha.web.repository.UserSosRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class UserSosService {
    private final UserSosRepository repository;

    public UserSosService(UserSosRepository repository) {
        this.repository = repository;
    }

    public SosResponse create(SosRequest request, String authenticatedUid) {
        validate(request);
        var existing = repository.findById(request.getId());
        if (existing.isPresent()) {
            if (!existing.get().getUserUid().equals(authenticatedUid)) {
                throw new SosConflictException("SOS ID already belongs to another user");
            }
            return SosResponse.from(existing.get());
        }

        UserSos sos = new UserSos();
        sos.setId(request.getId());
        sos.setUserUid(authenticatedUid);
        sos.setLatitude(request.getLatitude());
        sos.setLongitude(request.getLongitude());
        sos.setAccuracy(request.getAccuracy());
        sos.setMessage(request.getMessage());
        sos.setCreatedAt(request.getCreatedAt());
        sos.setStatus("RECEIVED");
        return SosResponse.from(repository.save(sos));
    }

    public List<SosResponse> all() {
        return repository.findAllByOrderByCreatedAtDesc().stream()
                .map(SosResponse::from).toList();
    }

    public List<SosResponse> all(String status) {
        var records = status == null || status.isBlank()
                ? repository.findAllByOrderByCreatedAtDesc()
                : repository.findByStatusOrderByCreatedAtDesc(status.toUpperCase());
        return records.stream().map(SosResponse::from).toList();
    }

    public SosResponse get(String id) {
        return repository.findById(id).map(SosResponse::from)
                .orElseThrow(() -> new SosNotFoundException(id));
    }

    public SosResponse updateStatus(String id, SosStatusRequest request) {
        var sos = repository.findById(id)
                .orElseThrow(() -> new SosNotFoundException(id));
        if (request.getStatus() == null || request.getStatus().isBlank()) {
            throw new IllegalArgumentException("status is required");
        }
        var next = request.getStatus().trim().toUpperCase();
        if (!isAllowedTransition(sos.getStatus(), next)) {
            throw new IllegalArgumentException(
                    "Invalid SOS status transition: " + sos.getStatus() + " -> " + next);
        }
        sos.setStatus(next);
        return SosResponse.from(repository.save(sos));
    }

    private boolean isAllowedTransition(String current, String next) {
        return switch (current) {
            case "RECEIVED" -> next.equals("ACKNOWLEDGED")
                    || next.equals("RESOLVED") || next.equals("CANCELLED");
            case "ACKNOWLEDGED" -> next.equals("RESOLVED") || next.equals("CANCELLED");
            default -> false;
        };
    }

    private void validate(SosRequest request) {
        if (!Double.isFinite(request.getLatitude()) || !Double.isFinite(request.getLongitude())
                || !Double.isFinite(request.getAccuracy())) {
            throw new IllegalArgumentException("coordinates and accuracy must be finite");
        }
        if ((request.getLatitude() < -90 || request.getLatitude() > 90)
                || (request.getLongitude() < -180 || request.getLongitude() > 180)) {
            throw new IllegalArgumentException("coordinates are outside valid ranges");
        }
        if (request.getAccuracy() < 0) {
            throw new IllegalArgumentException("accuracy must be non-negative");
        }
    }

    public static class SosConflictException extends RuntimeException {
        public SosConflictException(String message) { super(message); }
    }

    public static class SosNotFoundException extends RuntimeException {
        public SosNotFoundException(String id) { super("SOS not found: " + id); }
    }
}