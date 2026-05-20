package az.autoparts.api.identity.repo;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.identity.domain.User;

public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByPhone(String phone);

    boolean existsByPhone(String phone);

    List<User> findAllByIdIn(Collection<UUID> ids);
}
