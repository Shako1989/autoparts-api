package az.autoparts.api.catalog.api.admin.dto;

import java.util.List;
import java.util.UUID;

public record AdminPartResponse(
    UUID id,
    UUID categoryId,
    String categorySlug,
    String nameAz,
    String nameRu,
    String nameEn,
    String brand,
    String description,
    String defaultImageUrl,
    List<AdminPartNumberEntry> partNumbers,
    List<AdminFitmentEntry> fitments,
    List<AdminPartCalloutLocation> calloutLocations
) {}
