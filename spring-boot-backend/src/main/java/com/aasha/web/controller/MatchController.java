package com.aasha.web.controller;

import com.aasha.web.dto.MatchAiRequest;
import com.aasha.web.dto.MatchAiResponse;
import com.aasha.web.service.AiMatchingClient;
import com.aasha.web.service.CandidateRetrievalService;
import com.aasha.web.service.PhotoService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/v1/match")
public class MatchController {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(MatchController.class);
    private final CandidateRetrievalService candidates;
    private final AiMatchingClient ai;
    private final PhotoService photoService;
    private final com.aasha.web.service.IncidentService incidents;

    public MatchController(CandidateRetrievalService candidates, AiMatchingClient ai, PhotoService photoService,
                           com.aasha.web.service.IncidentService incidents) {
        this.candidates = candidates;
        this.ai = ai;
        this.photoService = photoService;
        this.incidents = incidents;
    }

    @PostMapping
    public ResponseEntity<MatchAiResponse> findMatches(@RequestBody Map<String, Object> body) {
        String incidentId = text(body.get("incident_id"));
        if (incidentId.isEmpty()) incidentId = text(body.get("incidentId"));
        incidents.requireActiveSearchable(incidentId);
        String name = text(body.get("name"));
        Integer age = number(body.get("age"));
        String location = text(body.get("lastKnownLocation"));
        if (location.isEmpty()) location = text(body.get("last_known_location"));
        String details = text(body.get("additionalDetails"));
        if (details.isEmpty()) details = text(body.get("additional_details"));
        String photo = text(body.get("photo"));

        try {
            String photoData = null;
            if (!photo.isEmpty()) {
                try {
                    byte[] image = photoService.getImageBytes(photo);
                    if (image != null) photoData = Base64.getEncoder().encodeToString(image);
                } catch (Exception e) {
                    log.error("Failed to read temporary photo: {}", photo, e);
                }
            }

            var candidatesList = candidates.retrieve(incidentId, name, age, location, details);
            log.info("[MATCHING-DEBUG] incident_id={} candidate_count={}", incidentId, candidatesList.size());

            MatchAiResponse response = ai.rank(new MatchAiRequest(
                    incidentId, name, age, location.isEmpty() ? null : location,
                    details.isEmpty() ? null : details,
                    photoData,
                    candidatesList));

            if (response != null && response.getResults() != null) {
                for (var result : response.getResults()) {
                    if (result.getIncidentId() != null && !incidentId.equals(result.getIncidentId())) {
                        throw new IllegalStateException("AI returned a result from another incident");
                    }
                    result.setIncidentId(incidentId);
                }
            }

            // Resolve each normal result from its own candidate reference at
            // the backend boundary. This keeps MinIO private and avoids
            // depending on the AI process having a phone-reachable base URL.
            resolveCandidatePhotoUrls(response, candidatesList);

            return ResponseEntity.ok(response);
        } finally {
            if (!photo.isEmpty()) {
                try {
                    photoService.deleteTemporary(photo);
                } catch (Exception e) {
                    log.warn("Failed to delete temporary photo: {}", photo);
                }
            }
        }
    }

    @PostMapping("/more")
    public ResponseEntity<MatchAiResponse> getMoreMatches(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ai.more(body));
    }

    private String text(Object value) { return value == null ? "" : value.toString().trim(); }
    private Integer number(Object value) { return value instanceof Number ? ((Number) value).intValue() : null; }

    private void resolveCandidatePhotoUrls(MatchAiResponse response, List<com.aasha.web.dto.MatchCandidate> candidates) {
        if (response == null || response.getResults() == null || candidates == null) return;
        Map<String, com.aasha.web.dto.MatchCandidate> byRecordId = new HashMap<>();
        for (var candidate : candidates) {
            byRecordId.put(candidate.recordId(), candidate);
        }
        for (var result : response.getResults()) {
            if (!"normal".equalsIgnoreCase(result.getRecordType())) continue;
            var candidate = byRecordId.get(result.getRecordId());
            if (candidate == null || candidate.photoUrl() == null || candidate.photoUrl().isBlank()) continue;
            String mediaUrl = photoService.getImageUrl(candidate.photoUrl());
            if (mediaUrl != null) result.setPhotoUrl(mediaUrl);
        }
    }
}
