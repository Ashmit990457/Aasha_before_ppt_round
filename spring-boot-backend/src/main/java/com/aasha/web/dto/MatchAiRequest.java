package com.aasha.web.dto;

import java.util.List;

public record MatchAiRequest(
        @com.fasterxml.jackson.annotation.JsonProperty("incident_id") String incidentId,
        String name,
        Integer age,
        String lastKnownLocation,
        String additionalDetails,
        String photo,
        List<MatchCandidate> candidates
) {}
