package az.autoparts.api.listings.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import az.autoparts.api.catalog.api.dto.PartSummary;
import az.autoparts.api.identity.api.dto.SellerSummary;
import az.autoparts.api.listings.domain.ListingCondition;
import az.autoparts.api.listings.domain.ListingStatus;

public record ListingDetail(
    UUID id,
    String title,
    String description,
    ListingCondition condition,
    ListingStatus status,
    long priceMinor,
    String currency,
    int quantity,
    String city,
    Instant publishedAt,
    Instant createdAt,
    PartSummary part,
    SellerSummary seller,
    List<ListingPhotoResponse> photos
) {}
