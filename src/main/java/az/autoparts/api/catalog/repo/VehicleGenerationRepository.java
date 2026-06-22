package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import az.autoparts.api.catalog.domain.VehicleGeneration;

public interface VehicleGenerationRepository extends JpaRepository<VehicleGeneration, UUID> {

    @Query("""
        select g from VehicleGeneration g
         where g.model.id = :modelId
         order by g.yearFrom asc
        """)
    List<VehicleGeneration> findAllByModelIdOrderByYearFromAsc(@Param("modelId") UUID modelId);

    @Query("""
        select g from VehicleGeneration g
         where g.model.make.slug = :makeSlug
           and g.model.slug = :modelSlug
         order by g.yearFrom asc
        """)
    List<VehicleGeneration> findAllByMakeSlugAndModelSlug(
        @Param("makeSlug") String makeSlug,
        @Param("modelSlug") String modelSlug
    );

    boolean existsByModelIdAndSlug(UUID modelId, String slug);

    boolean existsByModelIdAndSlugAndIdNot(UUID modelId, String slug, UUID id);

    @Query("""
        select g, count(v)
          from VehicleGeneration g
          left join VehicleVariant v on v.generation.id = g.id
         where g.model.id = :modelId
         group by g
         order by g.yearFrom asc, g.name asc
        """)
    List<Object[]> findAllWithVariantCountByModelId(@Param("modelId") UUID modelId);

    @Query("select count(v) from VehicleVariant v where v.generation.id = :generationId")
    long countVariantsByGenerationId(@Param("generationId") UUID generationId);
}
