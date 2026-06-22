package az.autoparts.api.catalog.api.admin.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateGenerationRequest(

    @Size(max = 40)
    String code,

    @Size(min = 1, max = 120)
    String name,

    @Size(min = 1, max = 120)
    @Pattern(regexp = "^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$",
        message = "slug must be lowercase letters, digits, or hyphens")
    String slug,

    @Min(1900) @Max(2100)
    Short yearFrom,

    @Min(1900) @Max(2100)
    Short yearTo
) {}
