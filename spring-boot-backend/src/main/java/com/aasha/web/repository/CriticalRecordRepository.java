package com.aasha.web.repository;

import com.aasha.web.entity.CriticalRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CriticalRecordRepository extends JpaRepository<CriticalRecord, String> {

    @Query("SELECT r FROM CriticalRecord r WHERE LOWER(r.name) LIKE LOWER(CONCAT('%', :name, '%'))")
    List<CriticalRecord> findByNameContaining(@Param("name") String name);

    @Query("SELECT r FROM CriticalRecord r WHERE LOWER(r.name) LIKE LOWER(CONCAT('%', :name, '%')) AND r.age = :age")
    List<CriticalRecord> findByNameAndAge(@Param("name") String name, @Param("age") int age);

    List<CriticalRecord> findByCampId(String campId);

    List<CriticalRecord> findTop20ByOrderByCreatedAtDesc();

    long countByStatus(String status);
}
