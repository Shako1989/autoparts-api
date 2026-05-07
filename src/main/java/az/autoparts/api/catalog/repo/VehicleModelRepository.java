package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.VehicleModel;

public interface VehicleModelRepository extends JpaRepository<VehicleModel, UUID> {

    List<VehicleModel> findAllByMakeIdOrderByNameAsc(UUID makeId);

    Optional<VehicleModel> findByMakeIdAndSlug(UUID makeId, String slug);
}
