package az.autoparts.api.catalog.api.dto;

import java.util.List;
import java.util.UUID;

public record CategoryDetailResponse(
    UUID id,
    UUID parentId,
    String slug,
    String name,
    String iconUrl,
    int sortOrder,
    List<CategoryResponse> children,
    List<CategoryBreadcrumb> breadcrumbs
) {
    public record CategoryBreadcrumb(UUID id, String slug, String name) {}
}
