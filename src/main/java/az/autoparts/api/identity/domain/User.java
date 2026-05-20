package az.autoparts.api.identity.domain;

import java.time.Instant;
import java.util.UUID;

import az.autoparts.api.common.auditing.AuditableEntity;
import az.autoparts.api.common.security.Role;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User extends AuditableEntity {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false, length = 20, unique = true)
    private String phone;

    @Column(name = "full_name", length = 160)
    private String fullName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    @Column(nullable = false)
    private boolean enabled;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;
}
