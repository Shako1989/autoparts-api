package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

public record AdminDiagramListItem(
    UUID id,
    String slug,
    String titleEn,
    UUID categoryId,
    String categorySlug,
    String imageUrl,
    long calloutCount
) {}
