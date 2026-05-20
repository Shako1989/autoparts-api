package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

public record PartSummary(
    UUID id,
    UUID categoryId,
    String categorySlug,
    String name,
    String brand,
    String defaultImageUrl
) {}
