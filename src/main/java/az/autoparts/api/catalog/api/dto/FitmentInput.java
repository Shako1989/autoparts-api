package az.autoparts.api.catalog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record FitmentInput(
    @NotBlank String makeSlug,
    @NotBlank String modelSlug,
    @NotNull @Positive Short year
) {}
