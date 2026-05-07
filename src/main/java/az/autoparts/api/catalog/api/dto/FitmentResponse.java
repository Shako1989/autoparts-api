package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

public record FitmentResponse(
    UUID id,
    UUID partId,
    UUID vehicleVariantId,
    String makeName,
    String modelName,
    short year,
    String trim,
    String engineCode,
    String position,
    String notes
) {}
