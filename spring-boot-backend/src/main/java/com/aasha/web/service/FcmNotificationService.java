package com.aasha.web.service;

import com.aasha.web.entity.Alert;
import com.aasha.web.entity.DeviceToken;
import com.aasha.web.repository.DeviceTokenRepository;
import com.aasha.web.repository.UserRepository;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class FcmNotificationService {
    private static final Logger log = LoggerFactory.getLogger(FcmNotificationService.class);

    private final DeviceTokenRepository tokenRepository;
    private final UserRepository userRepository;
    private final boolean enabled;
    private final String projectId;

    public FcmNotificationService(
            DeviceTokenRepository tokenRepository,
            UserRepository userRepository,
            @Value("${firebase.notifications.enabled:false}") boolean enabled,
            @Value("${firebase.project-id:}") String projectId) {
        this.tokenRepository = tokenRepository;
        this.userRepository = userRepository;
        this.enabled = enabled;
        this.projectId = projectId;
    }

    public int dispatch(Alert alert) {
        List<DeviceToken> targets = normalUserTokens();
        if (!enabled) {
            log.info("[ALERT-DEBUG] alert_id={} target_count={} notification_dispatch=NOT_CONFIGURED",
                    alert.getId(), targets.size());
            return 0;
        }
        if (targets.isEmpty()) {
            log.info("[ALERT-DEBUG] alert_id={} target_count=0 notification_dispatch=NO_REGISTERED_TOKENS",
                    alert.getId());
            return 0;
        }

        log.info("[ALERT-DEBUG] alert_id={} target_count={} notification_dispatch=STARTED",
                alert.getId(), targets.size());
        try {
            BatchResponse response = FirebaseMessaging.getInstance(firebaseApp()).sendEachForMulticast(
                    MulticastMessage.builder()
                            .addAllTokens(targets.stream().map(DeviceToken::getToken).toList())
                            .setNotification(Notification.builder()
                                    .setTitle(alert.getTitle())
                                    .setBody(alert.getMessage() == null ? "Emergency alert" : alert.getMessage())
                                    .build())
                            .setAndroidConfig(AndroidConfig.builder()
                                    .setPriority(AndroidConfig.Priority.HIGH)
                                    .setNotification(AndroidNotification.builder()
                                            .setChannelId("aasha_emergency_alerts")
                                            .build())
                                    .setTtl(86_400_000L)
                                    .build())
                            .putData("type", "GOVERNMENT_EMERGENCY_ALERT")
                            .putData("alert_id", String.valueOf(alert.getId()))
                            .putData("title", alert.getTitle())
                            .putData("message", alert.getMessage() == null ? "" : alert.getMessage())
                            .putData("severity", alert.getSeverity() == null ? "" : alert.getSeverity())
                            .putData("route", "emergency-alert")
                            .build());
            log.info("[ALERT-DEBUG] alert_id={} notification_dispatch=COMPLETED success_count={} failure_count={}",
                    alert.getId(), response.getSuccessCount(), response.getFailureCount());
            return response.getSuccessCount();
        } catch (Exception error) {
            log.error("[ALERT-DEBUG] alert_id={} notification_dispatch=FAILED error_type={} error={}",
                    alert.getId(), error.getClass().getSimpleName(), error.getMessage());
            return 0;
        }
    }

    private List<DeviceToken> normalUserTokens() {
        Set<String> normalUsers = userRepository.findAll().stream()
                .filter(user -> "user".equalsIgnoreCase(user.getRole()))
                .map(user -> user.getUid())
                .collect(Collectors.toSet());
        return tokenRepository.findByActiveTrue().stream()
                .filter(token -> normalUsers.contains(token.getUserUid()))
                .toList();
    }

    private FirebaseApp firebaseApp() throws Exception {
        if (!FirebaseApp.getApps().isEmpty()) return FirebaseApp.getInstance();
        FirebaseOptions.Builder options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.getApplicationDefault());
        if (projectId != null && !projectId.isBlank()) options.setProjectId(projectId);
        return FirebaseApp.initializeApp(options.build());
    }
}
