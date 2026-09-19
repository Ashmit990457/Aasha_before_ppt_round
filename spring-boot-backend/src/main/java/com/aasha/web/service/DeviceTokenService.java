package com.aasha.web.service;

import com.aasha.web.dto.DeviceTokenRequest;
import com.aasha.web.entity.DeviceToken;
import com.aasha.web.repository.DeviceTokenRepository;
import org.springframework.stereotype.Service;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Service
public class DeviceTokenService {
    private final DeviceTokenRepository repository;

    public DeviceTokenService(DeviceTokenRepository repository) { this.repository = repository; }

    public void register(String userUid, DeviceTokenRequest request) {
        String hash = sha256(request.token());
        DeviceToken token = repository.findByTokenHash(hash).orElseGet(DeviceToken::new);
        token.setUserUid(userUid);
        token.setToken(request.token());
        token.setTokenHash(hash);
        token.setPlatform(request.platform().trim().toLowerCase());
        token.setActive(true);
        repository.save(token);
    }

    private String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder result = new StringBuilder();
            for (byte item : digest) result.append(String.format("%02x", item));
            return result.toString();
        } catch (Exception error) {
            throw new IllegalStateException("Unable to hash device token", error);
        }
    }
}
