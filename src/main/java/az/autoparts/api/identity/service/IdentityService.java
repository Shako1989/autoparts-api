package az.autoparts.api.identity.service;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import az.autoparts.api.identity.api.dto.SellerSummary;
import az.autoparts.api.identity.api.dto.UserSummary;

/**
 * Cross-module read API. Other modules (listings, search) read seller/user info
 * through this interface — never via identity repositories directly.
 */
public interface IdentityService {

    Optional<UserSummary> getUserSummary(UUID userId);

    Optional<UUID> getSellerProfileIdForUser(UUID userId);

    Map<UUID, SellerSummary> getSellerSummaries(Collection<UUID> sellerProfileIds);
}
