package com.aasha.web.repository;

import com.aasha.web.entity.NormalRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NormalRecordRepository extends JpaRepository<NormalRecord, String> {

    @Query("SELECT r FROM NormalRecord r WHERE LOWER(r.name) LIKE LOWER(CONCAT('%', :name, '%'))")
    List<NormalRecord> findByNameContaining(@Param("name") String name);

    @Query("SELECT r FROM NormalRecord r WHERE LOWER(r.name) LIKE LOWER(CONCAT('%', :name, '%')) AND r.age = :age")
    List<NormalRecord> findByNameAndAge(@Param("name") String name, @Param("age") int age);

    List<NormalRecord> findByCampId(String campId);

    List<NormalRecord> findTop20ByOrderByCreatedAtDesc();

    long countByStatus(String status);
}
