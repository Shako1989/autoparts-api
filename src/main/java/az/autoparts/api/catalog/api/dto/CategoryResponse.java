package az.autoparts.api.catalog.api.dto;

import java.util.List;
import java.util.UUID;

public record CategoryResponse(
    UUID id,
    UUID parentId,
    String slug,
    String name,
    String iconUrl,
    int sortOrder,
    List<CategoryResponse> children
) {
    public static CategoryResponse leaf(UUID id, UUID parentId, String slug, String name, String iconUrl, int sortOrder) {
        return new CategoryResponse(id, parentId, slug, name, iconUrl, sortOrder, List.of());
    }
}
