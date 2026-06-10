package az.autoparts.api.identity.api.dto;

import java.util.UUID;

import az.autoparts.api.common.security.Role;

public record MeResponse(
    UUID id,
    String phone,
    String email,
    String fullName,
    Role role,
    boolean hasSellerProfile
) {}
