package az.autoparts.api.common.security;

import java.util.Optional;
import java.util.UUID;

/**
 * Resolves the live role of a user from the underlying source of truth (DB).
 * Used by {@link JwtAuthenticationFilter} so role changes take effect immediately
 * without requiring the user to re-login with a fresh JWT.
 *
 * Implemented in the identity module — common only owns the contract.
 */
public interface CurrentRoleResolver {

    Optional<Role> resolveRole(UUID userId);
}
