package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

public record UpdateCalloutRequest(
    UUID partId,
    @Size(max = 20) String label,
    @PositiveOrZero Integer x,
    @PositiveOrZero Integer y,
    @PositiveOrZero Integer w,
    @PositiveOrZero Integer h,
    @Min(0) Integer zOrder,
    @Size(max = 255) String notes
) {}
