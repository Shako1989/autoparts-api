package az.autoparts.api.identity.service.otp;

import az.autoparts.api.identity.domain.OtpPurpose;

public interface OtpSender {

    /**
     * Deliver the OTP code to the user.
     *
     * @param phone   user's phone (E.164). Always present.
     * @param email   user's email if known; may be null in dev profiles.
     * @param code    the plaintext 6-digit code.
     * @param purpose REGISTER or LOGIN.
     */
    void send(String phone, String email, String code, OtpPurpose purpose);

    /**
     * Local-dev only convenience: read back the latest unconsumed plaintext code
     * for a phone. Production senders must return {@link java.util.Optional#empty()}.
     */
    java.util.Optional<String> peekLatest(String phone);
}
