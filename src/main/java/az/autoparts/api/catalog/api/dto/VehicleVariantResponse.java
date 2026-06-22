package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

import az.autoparts.api.catalog.domain.FuelType;

public record VehicleVariantResponse(
    UUID id,
    UUID generationId,
    // modelId kept for backward compatibility with existing callers that
    // don't yet know about generations. New code should use generationId.
    UUID modelId,
    short year,
    String trim,
    String engineCode,
    String bodyType,
    FuelType fuel
) {}
