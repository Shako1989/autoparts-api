package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

public record VehicleMakeResponse(
    UUID id,
    String name,
    String slug,
    String logoUrl,
    int popularity
) {}
