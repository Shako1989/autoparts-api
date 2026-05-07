package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.VehicleMake;

public interface VehicleMakeRepository extends JpaRepository<VehicleMake, UUID> {

    Optional<VehicleMake> findBySlug(String slug);

    List<VehicleMake> findAllByOrderByPopularityDescNameAsc();
}
