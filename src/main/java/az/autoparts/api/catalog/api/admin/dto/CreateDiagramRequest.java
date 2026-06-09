package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record CreateDiagramRequest(
    @NotBlank @Size(max = 160)
    @Pattern(regexp = "^[a-z0-9](?:[a-z0-9-]{0,158}[a-z0-9])?$",
        message = "slug must be lowercase ASCII letters, digits, or hyphens")
    String slug,

    @NotBlank @Size(max = 255) String titleAz,
    @NotBlank @Size(max = 255) String titleRu,
    @NotBlank @Size(max = 255) String titleEn,

    @NotBlank @Size(max = 512) String imageUrl,
    @NotNull @Positive Integer imageWidth,
    @NotNull @Positive Integer imageHeight,

    UUID categoryId,
    UUID vehicleVariantId
) {}
