package com.aasha.web.controller;

import com.aasha.web.dto.AlertResponse;
import com.aasha.web.service.JwtService;
import com.aasha.web.repository.UserRepository;
import com.aasha.web.service.AlertService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import com.aasha.web.security.HeadOfficialAuthorization;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AlertController.class)
@AutoConfigureMockMvc(addFilters = true)
@Import({com.aasha.web.config.SecurityConfig.class, HeadOfficialAuthorization.class})
class AlertControllerTest {
    @Autowired MockMvc mockMvc;
    @MockBean AlertService service;
    @MockBean JwtService jwtService;
    @MockBean UserRepository userRepository;

    @Test
    void activeAlertsArePubliclyReadable() throws Exception {
        when(service.activeAlerts()).thenReturn(List.of(response()));

        mockMvc.perform(get("/api/alerts/active"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "USER")
    void normalUserCannotCreateAlert() throws Exception {
        mockMvc.perform(post("/api/alerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validJson()))
                .andExpect(status().isForbidden());
    }

    @Test
    void unauthenticatedUserCannotCreateAlert() throws Exception {
        mockMvc.perform(post("/api/alerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validJson()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(username = "ashmitsingh061@gmail.com", roles = "OFFICIAL")
    void headOfficialCanCreateAlert() throws Exception {
        when(service.create(any())).thenReturn(response());

        mockMvc.perform(post("/api/alerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validJson()))
                .andExpect(status().isCreated());
    }

    @Test
    @WithMockUser(username = "other.official@example.com", roles = "OFFICIAL")
    void normalOfficialCannotCreateAlert() throws Exception {
        mockMvc.perform(post("/api/alerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validJson()))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "other.official@example.com", roles = "OFFICIAL")
    void clientCannotImpersonateHeadOfficialInRequestBody() throws Exception {
        mockMvc.perform(post("/api/alerts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validJsonWithClientEmail()))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "ashmitsingh061@gmail.com", roles = "OFFICIAL")
    void headOfficialCanActivateOrDeactivateAlert() throws Exception {
        when(service.setActive(1L, false)).thenReturn(response());

        mockMvc.perform(patch("/api/alerts/1/active")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"active\":false}"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(username = "ashmitsingh061@gmail.com", roles = "OFFICIAL")
    void headOfficialCanUpdateAlert() throws Exception {
        when(service.update(any(), any())).thenReturn(response());

        mockMvc.perform(put("/api/alerts/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validJson()))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(username = "other.official@example.com", roles = "OFFICIAL")
    void normalOfficialCannotUpdateAlert() throws Exception {
        mockMvc.perform(put("/api/alerts/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validJson()))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "USER")
    void normalUserCannotDeactivateAlert() throws Exception {
        mockMvc.perform(patch("/api/alerts/1/active")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"active\":false}"))
                .andExpect(status().isForbidden());
    }

private AlertResponse response() {
        return new AlertResponse(1L, "incident-101", "Flood", "Move", "FLOOD", "SEVERE",
                "Raigad", "Maharashtra", 19.1, 72.9, 10.0, true,
                LocalDateTime.of(2026, 1, 1, 12, 0), 2.0, 5.0, 10.0);
    }

private String validJson() {
        return "{\"title\":\"Flood\",\"type\":\"FLOOD\",\"severity\":\"SEVERE\",\"latitude\":19.1,\"longitude\":72.9}";
    }

    private String validJsonWithClientEmail() {
        return "{\"email\":\"ashmitsingh061@gmail.com\",\"title\":\"Flood\",\"type\":\"FLOOD\",\"severity\":\"SEVERE\"}";
    }
}
