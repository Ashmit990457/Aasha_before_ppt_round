package com.aasha.web.controller;

import com.aasha.web.entity.CriticalRecord;
import com.aasha.web.entity.NormalRecord;
import com.aasha.web.repository.CriticalRecordRepository;
import com.aasha.web.repository.NormalRecordRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/v1/match")
public class MatchController {

    private final NormalRecordRepository normalRepo;
    private final CriticalRecordRepository criticalRepo;

    public MatchController(NormalRecordRepository normalRepo, CriticalRecordRepository criticalRepo) {
        this.normalRepo = normalRepo;
        this.criticalRepo = criticalRepo;
    }

    @PostMapping
    public ResponseEntity<?> findMatches(@RequestBody Map<String, Object> body) {
        String name = (String) body.getOrDefault("name", "");
        Integer age = null;
        Object ageObj = body.get("age");
        if (ageObj instanceof Number) {
            age = ((Number) ageObj).intValue();
        }

        List<Map<String, Object>> results = new ArrayList<>();

        // Search normal records
        List<NormalRecord> normalRecords;
        if (!name.isEmpty() && age != null) {
            normalRecords = normalRepo.findByNameAndAge(name, age);
        } else if (!name.isEmpty()) {
            normalRecords = normalRepo.findByNameContaining(name);
        } else {
            normalRecords = normalRepo.findTop20ByOrderByCreatedAtDesc();
        }

        for (NormalRecord r : normalRecords) {
            Map<String, Object> result = new HashMap<>();
            result.put("recordType", "normal");
            result.put("recordId", r.getId());
            result.put("name", r.getName());
            result.put("age", r.getAge());
            result.put("photoUrl", r.getPhotoUrl());
            result.put("campName", r.getCampName());
            result.put("officerName", r.getOfficerName());
            result.put("officerContact", r.getOfficerContact());
            result.put("status", r.getStatus());
            result.put("matchConfidence", calculateConfidence(name, age, r.getName(), r.getAge()));
            result.put("matchLabel", getMatchLabel(calculateConfidence(name, age, r.getName(), r.getAge())));
            results.add(result);
        }

        // Search critical records
        List<CriticalRecord> criticalRecords;
        if (!name.isEmpty() && age != null) {
            criticalRecords = criticalRepo.findByNameAndAge(name, age);
        } else if (!name.isEmpty()) {
            criticalRecords = criticalRepo.findByNameContaining(name);
        } else {
            criticalRecords = criticalRepo.findTop20ByOrderByCreatedAtDesc();
        }

        for (CriticalRecord r : criticalRecords) {
            Map<String, Object> result = new HashMap<>();
            result.put("recordType", "critical");
            result.put("recordId", r.getId());
            result.put("name", r.getName());
            result.put("age", r.getAge());
            result.put("lastKnownClothing", r.getLastKnownClothing());
            result.put("campName", r.getCampName());
            result.put("officerName", r.getOfficerName());
            result.put("officerContact", r.getOfficerContact());
            result.put("matchConfidence", calculateConfidence(name, age, r.getName(), r.getAge()));
            result.put("matchLabel", getMatchLabel(calculateConfidence(name, age, r.getName(), r.getAge())));
            results.add(result);
        }

        // Sort by confidence
        results.sort((a, b) -> Double.compare(
                (double) b.get("matchConfidence"),
                (double) a.get("matchConfidence")
        ));

        Map<String, Object> response = new HashMap<>();
        response.put("results", results);
        response.put("hasMore", false);
        response.put("requestId", UUID.randomUUID().toString());

        return ResponseEntity.ok(response);
    }

    @PostMapping("/more")
    public ResponseEntity<?> getMoreMatches(@RequestBody Map<String, Object> body) {
        Map<String, Object> response = new HashMap<>();
        response.put("results", List.of());
        response.put("hasMore", false);
        return ResponseEntity.ok(response);
    }

    private double calculateConfidence(String searchName, Integer searchAge, String dbName, Integer dbAge) {
        double score = 0.0;

        if (searchName != null && !searchName.isEmpty() && dbName != null) {
            String s = searchName.toLowerCase().trim();
            String d = dbName.toLowerCase().trim();
            if (d.equals(s)) {
                score += 0.6;
            } else if (d.contains(s) || s.contains(d)) {
                score += 0.4;
            } else if (d.startsWith(s) || s.startsWith(d)) {
                score += 0.3;
            } else {
                score += 0.1;
            }
        }

        if (searchAge != null && dbAge != null) {
            int diff = Math.abs(searchAge - dbAge);
            if (diff == 0) score += 0.3;
            else if (diff <= 2) score += 0.2;
            else if (diff <= 5) score += 0.1;
        }

        return Math.min(score, 1.0);
    }

    private String getMatchLabel(double confidence) {
        if (confidence >= 0.8) return "High Match";
        if (confidence >= 0.5) return "Possible Match";
        return "Low Match";
    }
}
