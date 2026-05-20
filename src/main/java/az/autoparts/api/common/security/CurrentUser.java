package az.autoparts.api.common.security;

import java.util.Optional;
import java.util.UUID;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class CurrentUser {

    private CurrentUser() {}

    public static Optional<UUID> id() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || auth.getPrincipal() == null) {
            return Optional.empty();
        }
        Object p = auth.getPrincipal();
        if (p instanceof UUID u) return Optional.of(u);
        if (p instanceof String s && !"anonymousUser".equals(s)) {
            try { return Optional.of(UUID.fromString(s)); } catch (IllegalArgumentException e) { return Optional.empty(); }
        }
        return Optional.empty();
    }

    public static UUID requireId() {
        return id().orElseThrow(() -> new IllegalStateException("No authenticated user in context"));
    }
}
