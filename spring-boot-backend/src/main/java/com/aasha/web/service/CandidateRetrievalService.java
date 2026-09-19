package com.aasha.web.service;

import com.aasha.web.dto.MatchCandidate;
import com.aasha.web.entity.CriticalRecord;
import com.aasha.web.entity.NormalRecord;
import com.aasha.web.repository.CriticalRecordRepository;
import com.aasha.web.repository.NormalRecordRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;

@Service
public class CandidateRetrievalService {
    private static final Logger log = LoggerFactory.getLogger(CandidateRetrievalService.class);

    private final NormalRecordRepository normalRepository;
    private final CriticalRecordRepository criticalRepository;
    private final int maxCandidates;
    private final int ageTolerance;

    public CandidateRetrievalService(
            NormalRecordRepository normalRepository,
            CriticalRecordRepository criticalRepository,
            @Value("${matching.candidate-pool-size:100}") int maxCandidates,
            @Value("${matching.age-tolerance:5}") int ageTolerance
    ) {
        this.normalRepository = normalRepository;
        this.criticalRepository = criticalRepository;
        this.maxCandidates = Math.max(1, maxCandidates);
        this.ageTolerance = Math.max(0, ageTolerance);
    }

    public List<MatchCandidate> retrieve(String incidentId, String name, Integer age, String location, String details) {
        log.info("[MATCHING-DEBUG] incident_id={} name={} age={} location={} details={}",
                incidentId, name, age, location, details);

        PageRequest retrievalLimit = PageRequest.of(0, maxCandidates);
        Map<String, MatchCandidate> candidates = new LinkedHashMap<>();

        List<NormalRecord> normalBroad = normalRepository.findTop20ByIncidentIdOrderByCreatedAtDesc(incidentId);
        List<CriticalRecord> criticalBroad = criticalRepository.findTop20ByIncidentIdOrderByCreatedAtDesc(incidentId);

        log.info("[MATCHING-DEBUG] incident_id={} normal_broad_count={} critical_broad_count={}",
                incidentId, normalBroad.size(), criticalBroad.size());

        addNormal(candidates, normalBroad);
        addCritical(candidates, criticalBroad);

        if (name != null && !name.isBlank()) {
            List<NormalRecord> normalByName = normalRepository.findByIncidentIdAndNameContainingLimited(incidentId, name.trim(), PageRequest.of(0, maxCandidates));
            List<CriticalRecord> criticalByName = criticalRepository.findByIncidentIdAndNameContainingLimited(incidentId, name.trim(), PageRequest.of(0, maxCandidates));
            log.info("[MATCHING-DEBUG] incident_id={} normal_name_count={} critical_name_count={}",
                    incidentId, normalByName.size(), criticalByName.size());
            addNormal(candidates, normalByName);
            addCritical(candidates, criticalByName);

            for (String token : name.trim().split("\\s+")) {
                if (token.length() >= 2) {
                    List<NormalRecord> normalByToken = normalRepository.findByIncidentIdAndToken(incidentId, token, PageRequest.of(0, maxCandidates));
                    List<CriticalRecord> criticalByToken = criticalRepository.findByIncidentIdAndToken(incidentId, token, PageRequest.of(0, maxCandidates));
                    log.info("[MATCHING-DEBUG] incident_id={} token={} normal_token_count={} critical_token_count={}",
                            incidentId, token, normalByToken.size(), criticalByToken.size());
                    addNormal(candidates, normalByToken);
                    addCritical(candidates, criticalByToken);
                }
            }
        }
        if (age != null) {
            List<NormalRecord> normalByAge = normalRepository.findByIncidentIdAndAgeBetween(incidentId, age - ageTolerance, age + ageTolerance, PageRequest.of(0, maxCandidates));
            List<CriticalRecord> criticalByAge = criticalRepository.findByIncidentIdAndAgeBetween(incidentId, age - ageTolerance, age + ageTolerance, PageRequest.of(0, maxCandidates));
            log.info("[MATCHING-DEBUG] incident_id={} normal_age_count={} critical_age_count={}",
                    incidentId, normalByAge.size(), criticalByAge.size());
            addNormal(candidates, normalByAge);
            addCritical(candidates, criticalByAge);
        }
        if (location != null && !location.isBlank()) {
            List<NormalRecord> normalByLocation = normalRepository.findByIncidentIdAndLocationContaining(incidentId, location.trim(), PageRequest.of(0, maxCandidates));
            List<CriticalRecord> criticalByLocation = criticalRepository.findByIncidentIdAndLocationContaining(incidentId, location.trim(), PageRequest.of(0, maxCandidates));
            log.info("[MATCHING-DEBUG] incident_id={} normal_location_count={} critical_location_count={}",
                    incidentId, normalByLocation.size(), criticalByLocation.size());
            addNormal(candidates, normalByLocation);
            addCritical(candidates, criticalByLocation);
        }

        log.info("[MATCHING-DEBUG] incident_id={} final_candidate_count={}", incidentId, candidates.size());

        return candidates.values().stream().limit(maxCandidates).toList();
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }

    private void addNormal(Map<String, MatchCandidate> target, List<NormalRecord> records) {
        records.forEach(record -> {
            String key = "normal:" + record.getId();
            target.putIfAbsent(key, new MatchCandidate(
                    safe(record.getId()),
                    safe(record.getIncidentId()),
                    "normal",
                    safe(record.getName()),
                    record.getAge(),
                    safe(record.getCampName()),
                    safe(record.getStatus()),
                    safe(record.getOfficerName()),
                    safe(record.getOfficerContact()),
                    safe(record.getPhotoUrl()),
                    null,
                    null,
                    safe(record.getAdditionalDetails())));
        });
    }

    private void addCritical(Map<String, MatchCandidate> target, List<CriticalRecord> records) {
        records.forEach(record -> {
            String key = "critical:" + record.getId();
            target.putIfAbsent(key, new MatchCandidate(
                    safe(record.getId()),
                    safe(record.getIncidentId()),
                    "critical",
                    safe(record.getName()),
                    record.getAge(),
                    safe(record.getCampName()),
                    safe(record.getStatus()),
                    safe(record.getOfficerName()),
                    safe(record.getOfficerContact()),
                    safe(record.getPhotoUrl()),
                    safe(record.getLastKnownClothing()),
                    safe(record.getFoundLocation()),
                    safe(record.getAdditionalDetails())));
        });
    }
}
