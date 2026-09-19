package com.aasha.web.security;

import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HeadOfficialAuthorizationTest {
    private final HeadOfficialAuthorization authorization =
            new HeadOfficialAuthorization("ashmitsingh061@gmail.com");

    @Test
    void configuredJwtEmailIsAllowedRegardlessOfRole() {
        var authentication = authentication("uid-1", "ashmitsingh061@gmail.com", "ROLE_OFFICIAL");

        assertTrue(authorization.isHeadOfficial(authentication));
    }

    @Test
    void differentOfficialEmailIsDenied() {
        var authentication = authentication("uid-2", "other@example.com", "ROLE_OFFICIAL");

        assertFalse(authorization.isHeadOfficial(authentication));
    }

    @Test
    void normalUserIsDenied() {
        var authentication = authentication("uid-3", "user@example.com", "ROLE_USER");

        assertFalse(authorization.isHeadOfficial(authentication));
    }

    @Test
    void unauthenticatedIsDenied() {
        assertFalse(authorization.isHeadOfficial(null));
    }

    @Test
    void requestBodyCannotChangeTrustedEmail() {
        var authentication = authentication("uid-4", "other@example.com", "ROLE_OFFICIAL");

        assertFalse(authorization.isHeadOfficial(authentication));
    }

    private UsernamePasswordAuthenticationToken authentication(
            String uid, String email, String role) {
        var authentication = new UsernamePasswordAuthenticationToken(
                uid, null, java.util.List.of(new SimpleGrantedAuthority(role)));
        authentication.setDetails(email);
        return authentication;
    }
}
