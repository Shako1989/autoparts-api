package az.autoparts.api.common.auditing;

import java.util.Optional;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.AuditorAware;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.stereotype.Component;

import az.autoparts.api.common.security.CurrentUser;

@Configuration
@EnableJpaAuditing(auditorAwareRef = "currentAuditorProvider")
public class JpaAuditingConfig {

    @Component("currentAuditorProvider")
    static class CurrentAuditorProvider implements AuditorAware<String> {
        @Override
        public Optional<String> getCurrentAuditor() {
            return CurrentUser.id().map(java.util.UUID::toString).or(() -> Optional.of("system"));
        }
    }
}
