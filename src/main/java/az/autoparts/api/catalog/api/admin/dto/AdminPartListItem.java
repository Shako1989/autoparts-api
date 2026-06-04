package az.autoparts.api.catalog.api.admin.dto;

import java.util.List;
import java.util.UUID;

public record AdminPartListItem(
    UUID id,
    UUID categoryId,
    String categorySlug,
    String nameEn,
    String brand,
    String defaultImageUrl,
    List<String> fits,
    int fitsTotal
) {}
