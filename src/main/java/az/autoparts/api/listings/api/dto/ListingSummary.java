package az.autoparts.api.listings.api.dto;

import java.time.Instant;
import java.util.UUID;

import az.autoparts.api.listings.domain.ListingCondition;
import az.autoparts.api.listings.domain.ListingStatus;

public record ListingSummary(
    UUID id,
    UUID partId,
    UUID sellerId,
    String sellerDisplayName,
    String sellerCity,
    String title,
    ListingCondition condition,
    ListingStatus status,
    long priceMinor,
    String currency,
    int quantity,
    String city,
    String thumbnailUrl,
    Instant createdAt
) {}
