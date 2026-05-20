package az.autoparts.api.identity.api.dto;

import az.autoparts.api.identity.domain.OtpPurpose;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record OtpRequest(
    @NotBlank
    @Pattern(regexp = "^\\+[1-9][0-9]{6,18}$", message = "phone must be E.164 (e.g. +994501234567)")
    String phone,

    @NotNull OtpPurpose purpose
) {}
