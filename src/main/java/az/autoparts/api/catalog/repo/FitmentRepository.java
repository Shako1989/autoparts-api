package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.Fitment;

public interface FitmentRepository extends JpaRepository<Fitment, UUID> {

    @EntityGraph(attributePaths = {"vehicleVariant", "vehicleVariant.model", "vehicleVariant.model.make"})
    List<Fitment> findAllByPartId(UUID partId);

    List<Fitment> findAllByVehicleVariantId(UUID vehicleVariantId);
}
