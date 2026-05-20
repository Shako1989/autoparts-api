package az.autoparts.api.identity.api.dto;

import java.time.Instant;

public record TokenResponse(
    String accessToken,
    String tokenType,
    long expiresInSeconds,
    Instant expiresAt,
    MeResponse user
) {}
