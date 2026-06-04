package az.autoparts.api.catalog.api.admin.dto;

import az.autoparts.api.catalog.domain.PartNumberType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreatePartNumberRequest(
    @NotBlank @Size(max = 80) String number,
    @NotNull PartNumberType type,
    @Size(max = 80) String source
) {}
