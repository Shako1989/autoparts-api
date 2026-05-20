package az.autoparts.api.identity.service;

import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.identity.api.dto.SellerSummary;
import az.autoparts.api.identity.api.dto.UserSummary;
import az.autoparts.api.identity.domain.SellerProfile;
import az.autoparts.api.identity.domain.User;
import az.autoparts.api.identity.repo.SellerProfileRepository;
import az.autoparts.api.identity.repo.UserRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
class IdentityServiceImpl implements IdentityService {

    private final UserRepository users;
    private final SellerProfileRepository sellers;

    @Override
    public Optional<UserSummary> getUserSummary(UUID userId) {
        return users.findById(userId)
            .map(u -> new UserSummary(u.getId(), u.getPhone(), u.getFullName()));
    }

    @Override
    public Optional<UUID> getSellerProfileIdForUser(UUID userId) {
        return sellers.findByUserId(userId).map(SellerProfile::getId);
    }

    @Override
    public Map<UUID, SellerSummary> getSellerSummaries(Collection<UUID> sellerProfileIds) {
        if (sellerProfileIds == null || sellerProfileIds.isEmpty()) return Map.of();
        List<SellerProfile> profiles = sellers.findAllByIdIn(sellerProfileIds);
        if (profiles.isEmpty()) return Map.of();
        List<UUID> userIds = profiles.stream().map(SellerProfile::getUserId).toList();
        Map<UUID, User> usersById = new HashMap<>();
        for (User u : users.findAllByIdIn(userIds)) usersById.put(u.getId(), u);
        Map<UUID, SellerSummary> out = new HashMap<>(profiles.size());
        for (SellerProfile p : profiles) {
            User u = usersById.get(p.getUserId());
            out.put(p.getId(), new SellerSummary(
                p.getId(),
                p.getUserId(),
                p.getDisplayName(),
                p.getCity(),
                p.getContactPhone() != null ? p.getContactPhone() : (u != null ? u.getPhone() : null),
                p.getWhatsapp()
            ));
        }
        return out;
    }
}
