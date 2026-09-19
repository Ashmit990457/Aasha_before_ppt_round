package com.aasha.web.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/** Authorization for government emergency-alert management only. */
@Component("headOfficialAuthorization")
public class HeadOfficialAuthorization {
    private final String configuredEmail;

    public HeadOfficialAuthorization(
            @Value("${head-official.email}") String configuredEmail) {
        this.configuredEmail = configuredEmail == null ? "" : configuredEmail.trim();
    }

    public boolean isHeadOfficial(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return false;
        }

        // JwtAuthFilter stores the verified JWT email in details. Do not read
        // an email from an alert request body or any client-supplied field.
        Object details = authentication.getDetails();
        // Mock/test authentications may expose the username as the principal;
        // production JWT authentications use the verified email in details.
        String authenticatedEmail = details instanceof String
                ? ((String) details).trim()
                : authentication.getName().trim();
        return !configuredEmail.isEmpty()
                && configuredEmail.equalsIgnoreCase(authenticatedEmail);
    }
}
