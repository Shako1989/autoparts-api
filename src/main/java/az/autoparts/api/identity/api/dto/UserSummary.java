package az.autoparts.api.identity.api.dto;

import java.util.UUID;

public record UserSummary(
    UUID id,
    String phone,
    String fullName
) {}
