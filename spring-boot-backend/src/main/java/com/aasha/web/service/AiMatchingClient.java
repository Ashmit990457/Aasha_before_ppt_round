package com.aasha.web.service;

import com.aasha.web.dto.MatchAiRequest;
import com.aasha.web.dto.MatchAiResponse;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Collections;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

@Service
public class AiMatchingClient {
    private final RestTemplate restTemplate;
    private final String aiUrl;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public AiMatchingClient(
            RestTemplate restTemplate,
            @Value("${matching.ai-url:http://localhost:8000/api/v1/match}") String aiUrl
    ) {
        this.restTemplate = restTemplate;
        this.aiUrl = aiUrl;
    }

    public MatchAiResponse rank(MatchAiRequest request) {
        try {
            // Log outgoing request for debugging
            logOutgoingRequest(request);

            ResponseEntity<MatchAiResponse> response = restTemplate.postForEntity(
                    aiUrl, jsonEntity(request), MatchAiResponse.class);

            logResponse(response);

            if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
                throw new MatchingServiceException("AI matching service returned an empty response");
            }
            return response.getBody();
        } catch (HttpClientErrorException error) {
            // Python service returned 4xx - log status and response body for debugging
            logPythonError("Client error", error.getStatusCode(), error.getResponseBodyAsString());
            throw new MatchingServiceException(
                    "AI matching service rejected request: HTTP " + error.getStatusCode(), error);
        } catch (HttpServerErrorException error) {
            // Python service returned 5xx
            logPythonError("Server error", error.getStatusCode(), error.getResponseBodyAsString());
            throw new MatchingServiceException(
                    "AI matching service internal error: HTTP " + error.getStatusCode(), error);
        } catch (ResourceAccessException error) {
            // Connection refused, timeout, network failure
            throw new MatchingServiceException("AI matching service is unreachable", error);
        } catch (RestClientException error) {
            // Other REST client errors
            throw new MatchingServiceException("AI matching service communication failed", error);
        }
    }

    public MatchAiResponse more(Map<String, Object> request) {
        try {
            ResponseEntity<MatchAiResponse> response = restTemplate.postForEntity(
                    aiUrl + "/more", jsonEntity(request), MatchAiResponse.class);

            logResponse(response);

            if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
                throw new MatchingServiceException("AI matching service returned an empty response");
            }
            return response.getBody();
        } catch (HttpClientErrorException error) {
            logPythonError("Client error", error.getStatusCode(), error.getResponseBodyAsString());
            throw new MatchingServiceException(
                    "AI matching service rejected request: HTTP " + error.getStatusCode(), error);
        } catch (HttpServerErrorException error) {
            logPythonError("Server error", error.getStatusCode(), error.getResponseBodyAsString());
            throw new MatchingServiceException(
                    "AI matching service internal error: HTTP " + error.getStatusCode(), error);
        } catch (ResourceAccessException error) {
            throw new MatchingServiceException("AI matching service is unreachable", error);
        } catch (RestClientException error) {
            throw new MatchingServiceException("AI matching service communication failed", error);
        }
    }

    private HttpEntity<MatchAiRequest> jsonEntity(MatchAiRequest request) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
        return new HttpEntity<>(request, headers);
    }

    private <T> HttpEntity<T> jsonEntity(T body) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
        return new HttpEntity<>(body, headers);
    }

    private void logOutgoingRequest(MatchAiRequest request) {
        try {
            String json = objectMapper.writeValueAsString(request);
            // Redact photo/base64 if present
            String safeJson = json;
            if (request.photo() != null && !request.photo().isEmpty()) {
                safeJson = safeJson.replaceFirst("(?s)\"photo\"\\s*:\\s*\"[^\"]*\"", "\"photo\":\"[REDACTED_BASE64]\"");
            }
            org.slf4j.LoggerFactory.getLogger(AiMatchingClient.class)
                    .info("[MATCH-AI-DEBUG] outgoing_request={}", safeJson);
        } catch (JsonProcessingException e) {
            org.slf4j.LoggerFactory.getLogger(AiMatchingClient.class)
                    .warn("[MATCH-AI-DEBUG] Failed to serialize outgoing request: {}", e.getMessage());
        }
    }

    private void logResponse(ResponseEntity<MatchAiResponse> response) {
        org.slf4j.LoggerFactory.getLogger(AiMatchingClient.class)
                .info("[MATCH-AI-DEBUG] downstream_status={}", response.getStatusCode());
        if (response.getBody() != null) {
            try {
                String json = objectMapper.writeValueAsString(response.getBody());
                org.slf4j.LoggerFactory.getLogger(AiMatchingClient.class)
                        .info("[MATCH-AI-DEBUG] downstream_body={}", json);
            } catch (JsonProcessingException e) {
                org.slf4j.LoggerFactory.getLogger(AiMatchingClient.class)
                        .warn("[MATCH-AI-DEBUG] Failed to serialize response body: {}", e.getMessage());
            }
        }
    }

    private void logPythonError(String type, org.springframework.http.HttpStatusCode status, String body) {
        // Log status and response body for debugging, but never log secrets/tokens
        String safeBody = body != null ? body.replaceAll("(?i)(token|secret|password|key)=\\S+", "$1=***") : "";
        org.slf4j.LoggerFactory.getLogger(AiMatchingClient.class)
                .error("[MATCH-AI-DEBUG] {} from Python service: status={}, body={}", type, status, safeBody);
    }

    public static class MatchingServiceException extends RuntimeException {
        public MatchingServiceException(String message) { super(message); }
        public MatchingServiceException(String message, Throwable cause) { super(message, cause); }
    }
}