package az.autoparts.api.identity.service;

import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.common.security.CurrentRoleResolver;
import az.autoparts.api.common.security.Role;
import az.autoparts.api.identity.repo.UserRepository;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
@Transactional(readOnly = true)
class CurrentRoleResolverImpl implements CurrentRoleResolver {

    private final UserRepository users;

    @Override
    public Optional<Role> resolveRole(UUID userId) {
        return users.findById(userId).map(u -> u.getRole());
    }
}
