package com.aasha.web.controller;

import com.aasha.web.dto.IncidentResponse;
import com.aasha.web.entity.Incident;
import com.aasha.web.service.IncidentService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.List;

@RestController
@RequestMapping("/api/incidents")
public class IncidentController {
    private final IncidentService service;

    public IncidentController(IncidentService service) { this.service = service; }

    @GetMapping({"", "/active"})
    public ResponseEntity<List<IncidentResponse>> active() {
        return ResponseEntity.ok(service.activeSearchable());
    }

    @GetMapping("/{id}")
    public ResponseEntity<IncidentResponse> getById(@PathVariable String id) {
        Incident incident = service.requireExisting(id);
        return ResponseEntity.ok(IncidentResponse.from(incident));
    }
}
