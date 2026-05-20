package az.autoparts.api.identity.service;

import java.math.BigDecimal;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.common.error.BadRequestException;
import az.autoparts.api.common.error.ResourceNotFoundException;
import az.autoparts.api.common.security.Role;
import az.autoparts.api.identity.api.dto.BecomeSellerRequest;
import az.autoparts.api.identity.api.dto.SellerProfileResponse;
import az.autoparts.api.identity.api.dto.UpdateSellerProfileRequest;
import az.autoparts.api.identity.domain.KycStatus;
import az.autoparts.api.identity.domain.SellerProfile;
import az.autoparts.api.identity.domain.User;
import az.autoparts.api.identity.repo.SellerProfileRepository;
import az.autoparts.api.identity.repo.UserRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
class SellerServiceImpl implements SellerService {

    private final UserRepository users;
    private final SellerProfileRepository sellers;

    @Override
    @Transactional
    public SellerProfileResponse becomeSeller(UUID userId, BecomeSellerRequest request) {
        User user = users.findById(userId)
            .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));
        if (sellers.findByUserId(userId).isPresent()) {
            throw new BadRequestException("Seller profile already exists for this user");
        }
        SellerProfile profile = sellers.save(SellerProfile.builder()
            .userId(userId)
            .displayName(request.displayName())
            .legalName(request.legalName())
            .city(request.city())
            .contactPhone(request.contactPhone())
            .whatsapp(request.whatsapp())
            .bio(request.bio())
            .kycStatus(KycStatus.UNVERIFIED)
            .ratingAvg(BigDecimal.ZERO)
            .ratingCount(0)
            .build());
        if (user.getRole() == Role.BUYER) {
            user.setRole(Role.SELLER);
            users.save(user);
        }
        return toResponse(profile);
    }

    @Override
    @Transactional(readOnly = true)
    public SellerProfileResponse getMyProfile(UUID userId) {
        return toResponse(sellers.findByUserId(userId)
            .orElseThrow(() -> new ResourceNotFoundException("Seller profile not found")));
    }

    @Override
    @Transactional
    public SellerProfileResponse updateMyProfile(UUID userId, UpdateSellerProfileRequest request) {
        SellerProfile profile = sellers.findByUserId(userId)
            .orElseThrow(() -> new ResourceNotFoundException("Seller profile not found"));
        if (request.displayName() != null && !request.displayName().isBlank()) {
            profile.setDisplayName(request.displayName());
        }
        if (request.legalName() != null) profile.setLegalName(request.legalName());
        if (request.city() != null) profile.setCity(request.city());
        if (request.contactPhone() != null) profile.setContactPhone(request.contactPhone());
        if (request.whatsapp() != null) profile.setWhatsapp(request.whatsapp());
        if (request.bio() != null) profile.setBio(request.bio());
        return toResponse(sellers.save(profile));
    }

    private SellerProfileResponse toResponse(SellerProfile p) {
        return new SellerProfileResponse(
            p.getId(),
            p.getUserId(),
            p.getDisplayName(),
            p.getLegalName(),
            p.getCity(),
            p.getContactPhone(),
            p.getWhatsapp(),
            p.getBio(),
            p.getKycStatus(),
            p.getRatingAvg(),
            p.getRatingCount()
        );
    }
}
