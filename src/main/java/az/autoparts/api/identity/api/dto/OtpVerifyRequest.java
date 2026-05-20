package az.autoparts.api.identity.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record OtpVerifyRequest(
    @NotBlank
    @Pattern(regexp = "^\\+[1-9][0-9]{6,18}$", message = "phone must be E.164 (e.g. +994501234567)")
    String phone,

    @NotBlank @Size(min = 4, max = 8) String code,

    @Size(max = 160) String fullName
) {}
