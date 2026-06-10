package az.autoparts.api.identity.service;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.UUID;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.common.error.BadRequestException;
import az.autoparts.api.common.error.ResourceNotFoundException;
import az.autoparts.api.common.security.JwtService;
import az.autoparts.api.common.security.Role;
import az.autoparts.api.identity.api.dto.MeResponse;
import az.autoparts.api.identity.api.dto.OtpRequest;
import az.autoparts.api.identity.api.dto.OtpVerifyRequest;
import az.autoparts.api.identity.api.dto.TokenResponse;
import az.autoparts.api.identity.domain.OtpCode;
import az.autoparts.api.identity.domain.OtpPurpose;
import az.autoparts.api.identity.domain.User;
import az.autoparts.api.identity.repo.OtpCodeRepository;
import az.autoparts.api.identity.repo.SellerProfileRepository;
import az.autoparts.api.identity.repo.UserRepository;
import az.autoparts.api.identity.service.otp.OtpSender;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
class AuthServiceImpl implements AuthService {

    private static final int CODE_LENGTH = 6;
    private static final long EXPIRES_IN_SECONDS = 600;
    private static final int MAX_ATTEMPTS = 5;

    private final UserRepository users;
    private final SellerProfileRepository sellers;
    private final OtpCodeRepository otps;
    private final OtpSender otpSender;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final AdminBootstrapProperties adminBootstrap;

    private final SecureRandom random = new SecureRandom();

    @Override
    @Transactional
    public void requestOtp(OtpRequest request) {
        String normalizedEmail = request.email() == null ? null : request.email().trim().toLowerCase();
        User existing = users.findByPhone(request.phone()).orElse(null);

        if (request.purpose() == OtpPurpose.LOGIN && existing == null) {
            throw new BadRequestException("No account for that phone — register instead");
        }
        if (existing != null && existing.getEmail() != null && normalizedEmail != null
            && !existing.getEmail().equalsIgnoreCase(normalizedEmail)) {
            throw new BadRequestException("Email does not match the account on file");
        }
        String deliveryEmail = normalizedEmail != null
            ? normalizedEmail
            : (existing != null ? existing.getEmail() : null);

        String code = generateCode();
        OtpCode entry = OtpCode.builder()
            .phone(request.phone())
            .email(deliveryEmail)
            .codeHash(encoder.encode(code))
            .purpose(request.purpose())
            .expiresAt(Instant.now().plusSeconds(EXPIRES_IN_SECONDS))
            .attempts((short) 0)
            .createdAt(Instant.now())
            .build();
        otps.save(entry);
        otpSender.send(request.phone(), deliveryEmail, code, request.purpose());
    }

    @Override
    @Transactional
    public TokenResponse verifyOtp(OtpVerifyRequest request) {
        OtpCode entry = otps
            .findTopByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(request.phone())
            .orElseThrow(() -> new BadRequestException("No active code — request a new one"));
        if (Instant.now().isAfter(entry.getExpiresAt())) {
            throw new BadRequestException("Code expired — request a new one");
        }
        if (entry.getAttempts() >= MAX_ATTEMPTS) {
            throw new BadRequestException("Too many attempts — request a new code");
        }
        if (!encoder.matches(request.code(), entry.getCodeHash())) {
            entry.setAttempts((short) (entry.getAttempts() + 1));
            otps.save(entry);
            throw new BadRequestException("Invalid code");
        }
        entry.setConsumedAt(Instant.now());
        otps.save(entry);

        User user = users.findByPhone(request.phone()).orElseGet(() -> users.save(
            User.builder()
                .phone(request.phone())
                .email(entry.getEmail())
                .fullName(request.fullName())
                .role(Role.BUYER)
                .enabled(true)
                .build()));
        if (user.getFullName() == null && request.fullName() != null && !request.fullName().isBlank()) {
            user.setFullName(request.fullName());
        }
        if (user.getEmail() == null && entry.getEmail() != null) {
            user.setEmail(entry.getEmail());
        }
        if (user.getRole() == Role.BUYER && adminBootstrap.isAllowlisted(user.getPhone())) {
            user.setRole(Role.STAFF);
        }
        user.setLastLoginAt(Instant.now());
        users.save(user);

        JwtService.TokenPair pair = jwt.issue(user.getId(), user.getRole(), user.getPhone());
        return new TokenResponse(
            pair.accessToken(),
            "Bearer",
            pair.expiresInSeconds(),
            pair.expiresAt(),
            toMe(user)
        );
    }

    @Override
    public MeResponse me(UUID userId) {
        User user = users.findById(userId)
            .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));
        return toMe(user);
    }

    private MeResponse toMe(User user) {
        boolean hasProfile = sellers.findByUserId(user.getId()).isPresent();
        return new MeResponse(
            user.getId(), user.getPhone(), user.getEmail(),
            user.getFullName(), user.getRole(), hasProfile);
    }

    private String generateCode() {
        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            sb.append(random.nextInt(10));
        }
        return sb.toString();
    }
}
