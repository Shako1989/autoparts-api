package az.autoparts.api.listings.api.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AddPhotoRequest(
    @NotBlank @Size(max = 255) String s3Key,
    @Min(0) Integer position
) {}
