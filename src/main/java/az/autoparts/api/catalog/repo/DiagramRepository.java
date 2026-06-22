package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import az.autoparts.api.catalog.domain.Diagram;

public interface DiagramRepository extends JpaRepository<Diagram, UUID> {

    Optional<Diagram> findBySlug(String slug);

    List<Diagram> findAllByCategoryId(UUID categoryId);

    List<Diagram> findAllByVehicleVariantId(UUID vehicleVariantId);

    /**
     * Diagrams in a category that have at least one callout whose part has a
     * fitment matching the given (make, model, year). Used by the buyer-side
     * category page to hide diagrams that are entirely incompatible with the
     * active vehicle.
     */
    @Query("""
        select distinct d from Diagram d
         where d.category.id = :categoryId
           and exists (
             select 1 from DiagramCallout dc
             join Fitment f on f.part.id = dc.part.id
             where dc.diagram.id = d.id
               and f.vehicleVariant.generation.model.make.slug = :makeSlug
               and f.vehicleVariant.generation.model.slug = :modelSlug
               and f.vehicleVariant.year = :year
           )
        """)
    List<Diagram> findCompatibleByCategoryIdAndMakeModelYear(
        @Param("categoryId") UUID categoryId,
        @Param("makeSlug") String makeSlug,
        @Param("modelSlug") String modelSlug,
        @Param("year") short year
    );
}
