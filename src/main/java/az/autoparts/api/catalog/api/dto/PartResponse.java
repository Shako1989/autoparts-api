package az.autoparts.api.catalog.api.dto;

import java.util.List;
import java.util.UUID;

import az.autoparts.api.catalog.domain.PartNumberType;

public record PartResponse(
    UUID id,
    UUID categoryId,
    String categorySlug,
    String name,
    String brand,
    String description,
    String defaultImageUrl,
    List<PartNumberEntry> partNumbers
) {
    public record PartNumberEntry(String number, PartNumberType type, String source) {}
}
