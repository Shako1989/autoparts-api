package az.autoparts.api.identity.repo;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.identity.domain.OtpCode;
import az.autoparts.api.identity.domain.OtpPurpose;

public interface OtpCodeRepository extends JpaRepository<OtpCode, UUID> {

    Optional<OtpCode> findTopByPhoneAndPurposeAndConsumedAtIsNullOrderByCreatedAtDesc(
        String phone, OtpPurpose purpose);

    Optional<OtpCode> findTopByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(String phone);
}
