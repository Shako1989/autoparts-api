package az.autoparts.api.listings.api.dto;

import java.util.UUID;

public record ListingPhotoResponse(
    UUID id,
    String url,
    int position
) {}
