package com.aasha.web.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "device_tokens")
public class DeviceToken {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_uid", nullable = false, length = 128)
    private String userUid;
    @Column(nullable = false, columnDefinition = "TEXT")
    private String token;
    @Column(name = "token_hash", nullable = false, unique = true, length = 64)
    private String tokenHash;
    @Column(nullable = false, length = 32)
    private String platform;
    @Column(nullable = false)
    private boolean active = true;
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = createdAt;
    }

    @PreUpdate
    void onUpdate() { updatedAt = LocalDateTime.now(); }

    public Long getId() { return id; }
    public String getUserUid() { return userUid; }
    public void setUserUid(String value) { userUid = value; }
    public String getToken() { return token; }
    public void setToken(String value) { token = value; }
    public String getTokenHash() { return tokenHash; }
    public void setTokenHash(String value) { tokenHash = value; }
    public String getPlatform() { return platform; }
    public void setPlatform(String value) { platform = value; }
    public boolean isActive() { return active; }
    public void setActive(boolean value) { active = value; }
}
