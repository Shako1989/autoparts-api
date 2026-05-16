package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.Diagram;

public interface DiagramRepository extends JpaRepository<Diagram, UUID> {

    Optional<Diagram> findBySlug(String slug);

    List<Diagram> findAllByCategoryId(UUID categoryId);

    List<Diagram> findAllByVehicleVariantId(UUID vehicleVariantId);
}
