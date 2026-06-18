package az.autoparts.api.identity.service.otp;

import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

import az.autoparts.api.common.error.BadRequestException;
import az.autoparts.api.identity.domain.OtpPurpose;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Production OTP sender — delivers the code by email via Spring's
 * {@link JavaMailSender}. Configure SMTP via Spring Boot's {@code spring.mail.*}
 * properties (host, port, username, password). Brevo's free tier (300/day)
 * works out of the box.
 *
 * Active only under the {@code prod} profile. {@link DevOtpSender} remains the
 * fallback for {@code default} and {@code local} profiles, where the code is
 * logged to stdout for /api/v1/dev/otp/{phone} retrieval.
 *
 * Forward-compat note: the {@link OtpSender} interface is intentionally stable
 * so a future notification service can host the impl over HTTP/queue without
 * touching the auth flow.
 */
@Component
@Profile("prod")
@RequiredArgsConstructor
@Slf4j
public class SmtpOtpSender implements OtpSender {

    private final JavaMailSender mailSender;

    @Value("${app.otp.email.from:no-reply@autoparts.az}")
    private String fromAddress;

    @Value("${app.otp.email.subject:Your AutoParts.az verification code}")
    private String subject;

    @Override
    public void send(String phone, String email, String code, OtpPurpose purpose) {
        if (email == null || email.isBlank()) {
            throw new BadRequestException(
                "No email on file for " + phone + " — email is required for OTP delivery in production.");
        }
        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setFrom(fromAddress);
        msg.setTo(email);
        msg.setSubject(subject);
        msg.setText(body(code, purpose));
        try {
            mailSender.send(msg);
            // TODO: remove plaintext code logging before public launch.
            log.info("Sent {} OTP to {} — code={}", purpose, mask(email), code);
        } catch (Exception e) {
            log.error("Failed to send OTP to {}: {}", mask(email), e.getMessage());
            throw new BadRequestException("Could not deliver the code. Try again in a moment.");
        }
    }

    @Override
    public Optional<String> peekLatest(String phone) {
        return Optional.empty();
    }

    private static String body(String code, OtpPurpose purpose) {
        String action = purpose == OtpPurpose.REGISTER ? "register" : "sign in";
        return """
            Your AutoParts.az verification code is:

                %s

            Enter this code in the app to %s. The code expires in 10 minutes.

            If you didn't request this code, you can ignore this email.
            """.formatted(code, action);
    }

    private static String mask(String email) {
        int at = email.indexOf('@');
        if (at <= 1) return "***";
        return email.charAt(0) + "***" + email.substring(at);
    }
}
