package az.autoparts.api.identity.service.otp;

import az.autoparts.api.identity.domain.OtpPurpose;

public interface OtpSender {

    void send(String phone, String code, OtpPurpose purpose);

    /**
     * Local-dev only convenience: read back the latest unconsumed plaintext code
     * for a phone. Production senders must return {@link java.util.Optional#empty()}.
     */
    java.util.Optional<String> peekLatest(String phone);
}
