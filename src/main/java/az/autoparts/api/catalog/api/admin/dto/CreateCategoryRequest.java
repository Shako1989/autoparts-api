package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateCategoryRequest(
    @NotBlank @Size(max = 120)
    @Pattern(regexp = "^[a-z0-9](?:[a-z0-9-]{0,118}[a-z0-9])?$",
        message = "slug must be lowercase ASCII letters, digits, or hyphens")
    String slug,

    UUID parentId,

    @NotBlank @Size(max = 160) String nameAz,
    @NotBlank @Size(max = 160) String nameRu,
    @NotBlank @Size(max = 160) String nameEn,

    @Size(max = 255) String iconUrl,

    @Min(0) Integer sortOrder
) {}
