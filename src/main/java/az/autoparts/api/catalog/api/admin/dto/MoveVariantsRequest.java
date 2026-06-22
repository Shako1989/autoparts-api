package az.autoparts.api.catalog.api.admin.dto;

import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record MoveVariantsRequest(

    @NotNull
    UUID targetGenerationId,

    @NotEmpty @Size(max = 200)
    List<@NotNull UUID> variantIds
) {}
