package az.autoparts.api.listings.api.dto;

import java.util.UUID;

import az.autoparts.api.listings.domain.ListingCondition;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record CreateListingRequest(
    @NotNull UUID partId,
    @NotBlank @Size(max = 255) String title,
    @Size(max = 4000) String description,
    @NotNull ListingCondition condition,
    @Positive long priceMinor,
    @NotBlank @Pattern(regexp = "^[A-Z]{3}$") String currency,
    @Min(0) int quantity,
    @Size(max = 80) String city
) {}
