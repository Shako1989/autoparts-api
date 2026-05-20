package az.autoparts.api.listings.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record PresignedUploadRequest(
    @NotBlank
    @Pattern(regexp = "^image/(jpeg|png|webp)$", message = "contentType must be image/jpeg, image/png, or image/webp")
    String contentType
) {}
