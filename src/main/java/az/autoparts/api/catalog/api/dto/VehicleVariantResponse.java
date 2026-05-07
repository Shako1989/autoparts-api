package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

import az.autoparts.api.catalog.domain.FuelType;

public record VehicleVariantResponse(
    UUID id,
    UUID modelId,
    short year,
    String trim,
    String engineCode,
    String bodyType,
    FuelType fuel
) {}
