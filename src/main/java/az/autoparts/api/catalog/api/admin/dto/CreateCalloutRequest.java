package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

public record CreateCalloutRequest(
    @NotNull UUID partId,
    @NotBlank @Size(max = 20) String label,
    @NotNull @PositiveOrZero Integer x,
    @NotNull @PositiveOrZero Integer y,
    @PositiveOrZero Integer w,
    @PositiveOrZero Integer h,
    @Min(0) Integer zOrder,
    @Size(max = 255) String notes
) {}
