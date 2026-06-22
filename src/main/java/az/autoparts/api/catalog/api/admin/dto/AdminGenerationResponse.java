package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

public record AdminGenerationResponse(
    UUID id,
    UUID modelId,
    String code,
    String name,
    String slug,
    short yearFrom,
    Short yearTo,
    long variantCount
) {}
