package az.autoparts.api.identity.service.otp;

import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import az.autoparts.api.identity.domain.OtpPurpose;
import lombok.extern.slf4j.Slf4j;

/**
 * Local-dev OTP sender. Logs the code to stdout and keeps a copy in memory so
 * the dev-only /dev/otp/{phone} endpoint can return it. Codes expire from the
 * in-memory map after 15 minutes.
 *
 * NEVER active in production — gated to local/default profiles.
 */
@Component
@Profile({"default", "local"})
@Slf4j
public class DevOtpSender implements OtpSender {

    private static final long TTL_SECONDS = 900;

    private final ConcurrentMap<String, Entry> cache = new ConcurrentHashMap<>();

    @Override
    public void send(String phone, String email, String code, OtpPurpose purpose) {
        cache.put(phone, new Entry(code, Instant.now().plusSeconds(TTL_SECONDS)));
        log.info("[DEV-OTP] {} ({}, purpose={}) -> {}", phone, email != null ? email : "no-email", purpose, code);
    }

    @Override
    public Optional<String> peekLatest(String phone) {
        Entry e = cache.get(phone);
        if (e == null) return Optional.empty();
        if (Instant.now().isAfter(e.expiresAt)) {
            cache.remove(phone, e);
            return Optional.empty();
        }
        return Optional.of(e.code);
    }

    private record Entry(String code, Instant expiresAt) {}
}
