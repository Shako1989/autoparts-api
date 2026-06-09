package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record UpdateDiagramRequest(
    @Size(max = 255) String titleAz,
    @Size(max = 255) String titleRu,
    @Size(max = 255) String titleEn,
    @Size(max = 512) String imageUrl,
    @Positive Integer imageWidth,
    @Positive Integer imageHeight,
    UUID categoryId,
    UUID vehicleVariantId
) {}
