package az.autoparts.api.search.api.dto;

import java.util.UUID;

public record SearchHit(
    UUID partId,
    String name,
    String brand,
    String categorySlug,
    String defaultImageUrl,
    long activeListings,
    Long minPriceMinor,
    String currency
) {}
