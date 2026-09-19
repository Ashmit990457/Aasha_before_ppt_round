package com.aasha.web.controller;

import com.aasha.web.dto.SosRequest;
import com.aasha.web.dto.SosResponse;
import com.aasha.web.dto.SosStatusRequest;
import com.aasha.web.service.UserSosService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/sos")
public class UserSosController {
    private static final Logger log = LoggerFactory.getLogger(UserSosController.class);
    private final UserSosService service;

    public UserSosController(UserSosService service) { this.service = service; }

    @PostMapping
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<SosResponse> create(
            @Valid @RequestBody SosRequest request,
            Authentication authentication
    ) {
        var response = service.create(request, authentication.getName());
        log.info("[SOS-OFFICIAL-DEBUG] submitted_sos_id={} db_insert=SUCCESS", response.id());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping
    @PreAuthorize("hasRole('OFFICIAL')")
    public ResponseEntity<List<SosResponse>> all(
            @RequestParam(required = false) String status,
            Authentication authentication
    ) {
        var responses = status == null ? service.all() : service.all(status);
        log.info("[SOS-OFFICIAL-DEBUG] official_user=authenticated official_role={} status_filter={} official_query_count={} returned_sos_ids={}",
                authentication.getAuthorities(), status, responses.size(),
                responses.stream().map(SosResponse::id).toList());
        return ResponseEntity.ok(responses);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('OFFICIAL')")
    public ResponseEntity<SosResponse> get(@PathVariable String id) {
        var response = service.get(id);
        log.info("[SOS-OFFICIAL-DEBUG] official_detail_sos_id={} status={}", id, response.status());
        return ResponseEntity.ok(response);
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('OFFICIAL')")
    public ResponseEntity<SosResponse> updateStatus(
            @PathVariable String id,
            @Valid @RequestBody SosStatusRequest request
    ) {
        return ResponseEntity.ok(service.updateStatus(id, request));
    }

    @ExceptionHandler({IllegalArgumentException.class})
    public ResponseEntity<Map<String, String>> badRequest(IllegalArgumentException exception) {
        return ResponseEntity.badRequest().body(Map.of("error", exception.getMessage()));
    }

    @ExceptionHandler(UserSosService.SosConflictException.class)
    public ResponseEntity<Map<String, String>> conflict(UserSosService.SosConflictException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("error", exception.getMessage()));
    }

    @ExceptionHandler(UserSosService.SosNotFoundException.class)
    public ResponseEntity<Void> notFound() { return ResponseEntity.notFound().build(); }
}
