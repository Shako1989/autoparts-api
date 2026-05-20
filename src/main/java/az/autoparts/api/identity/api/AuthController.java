package az.autoparts.api.identity.api;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.common.security.CurrentUser;
import az.autoparts.api.identity.api.dto.MeResponse;
import az.autoparts.api.identity.api.dto.OtpRequest;
import az.autoparts.api.identity.api.dto.OtpVerifyRequest;
import az.autoparts.api.identity.api.dto.TokenResponse;
import az.autoparts.api.identity.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/otp/request")
    public ResponseEntity<Void> requestOtp(@Valid @RequestBody OtpRequest request) {
        authService.requestOtp(request);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/otp/verify")
    public TokenResponse verifyOtp(@Valid @RequestBody OtpVerifyRequest request) {
        return authService.verifyOtp(request);
    }

    @GetMapping("/me")
    public MeResponse me() {
        return authService.me(CurrentUser.requireId());
    }
}
