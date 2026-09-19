package com.aasha.web.dto;

import jakarta.validation.constraints.NotBlank;

public record DeviceTokenRequest(@NotBlank String token, @NotBlank String platform) {}
