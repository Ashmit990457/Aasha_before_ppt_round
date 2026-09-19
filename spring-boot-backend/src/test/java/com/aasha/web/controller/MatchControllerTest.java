package com.aasha.web.controller;

import com.aasha.web.dto.MatchAiResponse;
import com.aasha.web.dto.MatchCandidate;
import com.aasha.web.service.AiMatchingClient;
import com.aasha.web.service.CandidateRetrievalService;
import com.aasha.web.service.PhotoService;
import com.aasha.web.service.IncidentService;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class MatchControllerTest {
    @Test
    void resolvesEachNormalResultPhotoFromItsMatchingCandidate() throws Exception {
        CandidateRetrievalService candidates = mock(CandidateRetrievalService.class);
        AiMatchingClient ai = mock(AiMatchingClient.class);
        PhotoService photos = mock(PhotoService.class);
        IncidentService incidents = mock(IncidentService.class);
        MatchController controller = new MatchController(candidates, ai, photos, incidents);

        String reference = "{\"provider\":\"minio\",\"storageId\":\"normal/record/photo.webp\"}";
        MatchCandidate candidate = new MatchCandidate(
                "record-1", "incident-101", "normal", "Ganpati", 20, "Camp", "AT_CAMP",
                "Officer", "", reference, null, null, null);
        when(candidates.retrieve(any(), any(), any(), any(), any())).thenReturn(List.of(candidate));
        when(photos.getImageBytes(any())).thenReturn(null);
        when(photos.getImageUrl(reference)).thenReturn("/api/v1/images/file/normal/record/photo.webp");

        MatchAiResponse.Result result = new MatchAiResponse.Result();
        result.setRecordId("record-1");
        result.setRecordType("normal");
        result.setName("Ganpati");
        result.setAge(20);
        result.setPhotoUrl(null);
        MatchAiResponse aiResponse = new MatchAiResponse();
        aiResponse.setResults(List.of(result));
        when(ai.rank(any())).thenReturn(aiResponse);

        var response = controller.findMatches(Map.of("incident_id", "incident-101", "name", "Ganpati", "age", 20));

        assertEquals("/api/v1/images/file/normal/record/photo.webp",
                response.getBody().getResults().get(0).getPhotoUrl());
    }
}
