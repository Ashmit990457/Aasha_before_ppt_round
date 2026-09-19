package com.aasha.web.controller;

import com.aasha.web.dto.DeviceTokenRequest;
import com.aasha.web.service.DeviceTokenService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/notifications")
public class DeviceTokenController {
    private static final Logger log = LoggerFactory.getLogger(DeviceTokenController.class);
    private final DeviceTokenService service;

    public DeviceTokenController(DeviceTokenService service) { this.service = service; }

    @PostMapping("/device-token")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Void> register(
            @Valid @RequestBody DeviceTokenRequest request,
            Authentication authentication) {
        service.register(authentication.getName(), request);
        log.info("[FCM-DEBUG] user_id={} token_registered=true", authentication.getName());
        return ResponseEntity.ok().build();
    }
}
