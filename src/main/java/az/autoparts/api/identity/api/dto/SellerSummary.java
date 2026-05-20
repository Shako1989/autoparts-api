package az.autoparts.api.identity.api.dto;

import java.util.UUID;

public record SellerSummary(
    UUID id,
    UUID userId,
    String displayName,
    String city,
    String contactPhone,
    String whatsapp
) {}
