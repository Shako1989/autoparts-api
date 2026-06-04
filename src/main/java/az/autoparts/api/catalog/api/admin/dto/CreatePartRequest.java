package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreatePartRequest(
    @NotNull UUID categoryId,
    @NotBlank @Size(max = 255) String nameAz,
    @NotBlank @Size(max = 255) String nameRu,
    @NotBlank @Size(max = 255) String nameEn,
    @Size(max = 120) String brand,
    @Size(max = 4000) String description,
    @Size(max = 255) String defaultImageUrl
) {}
