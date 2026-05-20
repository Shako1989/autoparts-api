package az.autoparts.api.identity.service;

import java.util.UUID;

import az.autoparts.api.identity.api.dto.MeResponse;
import az.autoparts.api.identity.api.dto.OtpRequest;
import az.autoparts.api.identity.api.dto.OtpVerifyRequest;
import az.autoparts.api.identity.api.dto.TokenResponse;

public interface AuthService {

    void requestOtp(OtpRequest request);

    TokenResponse verifyOtp(OtpVerifyRequest request);

    MeResponse me(UUID userId);
}
