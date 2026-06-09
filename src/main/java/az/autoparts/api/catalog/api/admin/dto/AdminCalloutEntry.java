package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

public record AdminCalloutEntry(
    UUID id,
    String label,
    int x,
    int y,
    Integer w,
    Integer h,
    int zOrder,
    String notes,
    UUID partId,
    String partName
) {}
