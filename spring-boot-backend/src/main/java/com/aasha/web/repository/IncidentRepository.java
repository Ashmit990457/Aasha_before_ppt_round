package com.aasha.web.repository;

import com.aasha.web.entity.Incident;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface IncidentRepository extends JpaRepository<Incident, String> {
    List<Incident> findByActiveTrueAndSearchableTrueOrderByCreatedAtDesc();
}
