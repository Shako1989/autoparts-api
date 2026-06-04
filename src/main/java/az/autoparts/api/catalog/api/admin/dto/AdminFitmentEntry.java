package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

public record AdminFitmentEntry(
    UUID id,
    UUID vehicleVariantId,
    String makeName,
    String modelName,
    short year,
    String trim,
    String engineCode,
    String position
) {}
