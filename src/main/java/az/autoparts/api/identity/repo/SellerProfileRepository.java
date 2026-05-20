package az.autoparts.api.identity.repo;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.identity.domain.SellerProfile;

public interface SellerProfileRepository extends JpaRepository<SellerProfile, UUID> {

    Optional<SellerProfile> findByUserId(UUID userId);

    List<SellerProfile> findAllByIdIn(Collection<UUID> ids);
}
