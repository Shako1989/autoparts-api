package az.autoparts.api.listings.api.dto;

import az.autoparts.api.listings.domain.ListingCondition;
import az.autoparts.api.listings.domain.ListingStatus;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record UpdateListingRequest(
    @Size(max = 255) String title,
    @Size(max = 4000) String description,
    ListingCondition condition,
    @Positive Long priceMinor,
    @Pattern(regexp = "^[A-Z]{3}$") String currency,
    @Min(0) Integer quantity,
    @Size(max = 80) String city,
    ListingStatus status
) {}
