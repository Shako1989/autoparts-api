package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import az.autoparts.api.catalog.domain.VehicleGeneration;
import az.autoparts.api.catalog.domain.VehicleVariant;

public interface VehicleVariantRepository extends JpaRepository<VehicleVariant, UUID> {

    // Generation-scoped queries — preferred for new code (matches the
    // canonical Make → Model → Generation → Year → Variant flow).

    @Query("""
        select v from VehicleVariant v
         where v.generation.id = :generationId
           and v.year = :year
         order by v.trim asc
        """)
    List<VehicleVariant> findAllByGenerationIdAndYearOrderByTrimAsc(
        @Param("generationId") UUID generationId,
        @Param("year") short year
    );

    @Query("""
        select distinct v.year from VehicleVariant v
         where v.generation.id = :generationId
         order by v.year
        """)
    List<Short> findDistinctYearsByGenerationId(@Param("generationId") UUID generationId);

    // Model-scoped queries — aggregate across all generations of the model.
    // Used by the legacy /years and /variants?model=... endpoints, and by
    // fitments creation where the caller doesn't pick a specific generation.

    @Query("""
        select v from VehicleVariant v
         where v.generation.model.id = :modelId
           and v.year = :year
         order by v.trim asc
        """)
    List<VehicleVariant> findAllByModelIdAndYearOrderByTrimAsc(
        @Param("modelId") UUID modelId,
        @Param("year") short year
    );

    @Query("""
        select distinct v.year from VehicleVariant v
         where v.generation.model.id = :modelId
         order by v.year
        """)
    List<Short> findDistinctYearsByModelId(@Param("modelId") UUID modelId);

    @Query("""
        select v from VehicleVariant v
         where v.generation.model.make.slug = :makeSlug
           and v.generation.model.slug = :modelSlug
           and v.year = :year
        """)
    List<VehicleVariant> findAllByMakeSlugAndModelSlugAndYear(
        @Param("makeSlug") String makeSlug,
        @Param("modelSlug") String modelSlug,
        @Param("year") short year
    );

    List<VehicleVariant> findAllByGenerationIdAndIdIn(UUID generationId, List<UUID> ids);

    @Modifying
    @Query("update VehicleVariant v set v.generation = :target where v.id in :ids")
    int bulkReassignToGeneration(
        @Param("target") VehicleGeneration target,
        @Param("ids") List<UUID> ids
    );
}
