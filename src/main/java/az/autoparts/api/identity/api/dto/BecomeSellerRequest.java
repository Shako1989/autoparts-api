package az.autoparts.api.identity.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record BecomeSellerRequest(
    @NotBlank @Size(max = 160) String displayName,
    @Size(max = 255) String legalName,
    @Size(max = 80) String city,
    @Size(max = 20) String contactPhone,
    @Size(max = 20) String whatsapp,
    @Size(max = 2000) String bio
) {}
