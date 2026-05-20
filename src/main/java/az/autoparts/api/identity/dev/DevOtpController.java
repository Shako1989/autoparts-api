package az.autoparts.api.identity.dev;

import java.util.Map;

import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.identity.service.otp.OtpSender;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;

/**
 * Local-only OTP read-back. Returns the latest unconsumed plaintext code for a
 * phone, as stashed by {@link az.autoparts.api.identity.service.otp.DevOtpSender}.
 */
@RestController
@RequestMapping("/api/v1/dev/otp")
@Profile({"default", "local"})
@RequiredArgsConstructor
@Tag(name = "Dev — local only", description = "Endpoints available only with spring.profiles.active=local")
public class DevOtpController {

    private final OtpSender otpSender;

    @GetMapping("/{phone}")
    @Operation(summary = "Latest unconsumed OTP for a phone (dev only)")
    public ResponseEntity<Map<String, String>> latest(@PathVariable String phone) {
        return otpSender.peekLatest(phone)
            .map(code -> ResponseEntity.ok(Map.of("phone", phone, "code", code)))
            .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
