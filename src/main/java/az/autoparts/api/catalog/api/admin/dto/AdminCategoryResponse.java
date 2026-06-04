package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

public record AdminCategoryResponse(
    UUID id,
    UUID parentId,
    String slug,
    String nameAz,
    String nameRu,
    String nameEn,
    String iconUrl,
    int sortOrder,
    long childCount,
    long partCount
) {}
