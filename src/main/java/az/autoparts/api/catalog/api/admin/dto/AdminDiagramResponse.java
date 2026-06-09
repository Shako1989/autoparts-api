package az.autoparts.api.catalog.api.admin.dto;

import java.util.List;
import java.util.UUID;

public record AdminDiagramResponse(
    UUID id,
    String slug,
    String titleAz,
    String titleRu,
    String titleEn,
    String imageUrl,
    int imageWidth,
    int imageHeight,
    UUID categoryId,
    String categorySlug,
    UUID vehicleVariantId,
    List<AdminCalloutEntry> callouts
) {}
