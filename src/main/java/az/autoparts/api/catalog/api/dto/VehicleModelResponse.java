package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

public record VehicleModelResponse(
    UUID id,
    UUID makeId,
    String name,
    String slug,
    short yearFrom,
    Short yearTo
) {}
