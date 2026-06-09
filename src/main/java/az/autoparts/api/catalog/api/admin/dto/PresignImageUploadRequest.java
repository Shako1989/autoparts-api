package az.autoparts.api.catalog.api.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record PresignImageUploadRequest(
    @NotBlank
    @Pattern(regexp = "^image/(jpeg|png|webp|svg\\+xml)$",
        message = "contentType must be image/jpeg, image/png, image/webp, or image/svg+xml")
    String contentType
) {}
