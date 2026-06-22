package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

public record VehicleGenerationResponse(
    UUID id,
    UUID modelId,
    String code,
    String name,
    String slug,
    short yearFrom,
    Short yearTo
) {}
