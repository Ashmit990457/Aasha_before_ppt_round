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

    public MatchController(CandidateRetrievalService candidates, AiMatchingClient ai, PhotoService photoService) {
        this.candidates = candidates;
        this.ai = ai;
        this.photoService = photoService;
    }

    @PostMapping
    public ResponseEntity<MatchAiResponse> findMatches(@RequestBody Map<String, Object> body) {
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

            var candidatesList = candidates.retrieve(name, age, location, details);
            log.info("Retrieved {} candidates for AI ranking", candidatesList.size());

            MatchAiResponse response = ai.rank(new MatchAiRequest(
                    name, age, location.isEmpty() ? null : location,
                    details.isEmpty() ? null : details,
                    photoData,
                    candidatesList));

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
}
