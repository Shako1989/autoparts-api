package az.autoparts.api.identity.service;

import java.util.UUID;

import az.autoparts.api.identity.api.dto.BecomeSellerRequest;
import az.autoparts.api.identity.api.dto.SellerProfileResponse;
import az.autoparts.api.identity.api.dto.UpdateSellerProfileRequest;

public interface SellerService {

    SellerProfileResponse becomeSeller(UUID userId, BecomeSellerRequest request);

    SellerProfileResponse getMyProfile(UUID userId);

    SellerProfileResponse updateMyProfile(UUID userId, UpdateSellerProfileRequest request);
}
