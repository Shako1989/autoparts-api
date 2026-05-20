package az.autoparts.api.listings.api.dto;

import java.util.UUID;

public record PartListingStats(
    UUID partId,
    long activeCount,
    Long minPriceMinor,
    String currency
) {
    public static PartListingStats empty(UUID partId) {
        return new PartListingStats(partId, 0L, null, null);
    }
}
