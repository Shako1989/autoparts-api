package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.Size;

public record UpdatePartRequest(
    UUID categoryId,
    @Size(max = 255) String nameAz,
    @Size(max = 255) String nameRu,
    @Size(max = 255) String nameEn,
    @Size(max = 120) String brand,
    @Size(max = 4000) String description,
    @Size(max = 255) String defaultImageUrl
) {}
