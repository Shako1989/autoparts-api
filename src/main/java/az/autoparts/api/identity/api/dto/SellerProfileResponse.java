package az.autoparts.api.identity.api.dto;

import java.math.BigDecimal;
import java.util.UUID;

import az.autoparts.api.identity.domain.KycStatus;

public record SellerProfileResponse(
    UUID id,
    UUID userId,
    String displayName,
    String legalName,
    String city,
    String contactPhone,
    String whatsapp,
    String bio,
    KycStatus kycStatus,
    BigDecimal ratingAvg,
    int ratingCount
) {}
