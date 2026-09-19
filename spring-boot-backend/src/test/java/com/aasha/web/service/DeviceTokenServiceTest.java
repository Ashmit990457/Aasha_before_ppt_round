package com.aasha.web.service;

import com.aasha.web.dto.DeviceTokenRequest;
import com.aasha.web.entity.DeviceToken;
import com.aasha.web.repository.DeviceTokenRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DeviceTokenServiceTest {
    @Mock DeviceTokenRepository repository;
    @InjectMocks DeviceTokenService service;

    @Test
    void registersTokenForAuthenticatedUserAndNormalizesPlatform() {
        when(repository.findByTokenHash(any())).thenReturn(java.util.Optional.empty());

        service.register("user-1", new DeviceTokenRequest("token-value", " Android "));

        ArgumentCaptor<DeviceToken> captor = ArgumentCaptor.forClass(DeviceToken.class);
        verify(repository).save(captor.capture());
        assertEquals("user-1", captor.getValue().getUserUid());
        assertEquals("android", captor.getValue().getPlatform());
        assertEquals("token-value", captor.getValue().getToken());
        assertEquals(64, captor.getValue().getTokenHash().length());
    }
}
