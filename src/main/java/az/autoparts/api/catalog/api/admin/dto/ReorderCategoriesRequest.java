package az.autoparts.api.catalog.api.admin.dto;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

public record ReorderCategoriesRequest(
    @NotEmpty @Valid List<Entry> entries
) {
    public record Entry(@NotNull UUID id, @NotNull @Min(0) Integer sortOrder) {}
}
