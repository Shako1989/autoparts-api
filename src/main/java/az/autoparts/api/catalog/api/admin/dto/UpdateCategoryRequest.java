package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record UpdateCategoryRequest(
    @Size(max = 160) String nameAz,
    @Size(max = 160) String nameRu,
    @Size(max = 160) String nameEn,
    @Size(max = 255) String iconUrl,
    UUID parentId,
    @Min(0) Integer sortOrder
) {}
