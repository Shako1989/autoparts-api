package az.autoparts.api.catalog.repo;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import az.autoparts.api.catalog.domain.Part;

public interface PartRepository extends JpaRepository<Part, UUID> {

    @EntityGraph(attributePaths = {"category"})
    Optional<Part> findWithCategoryById(UUID id);

    @EntityGraph(attributePaths = {"category"})
    @Query("select p from Part p where p.deletedAt is null and p.category.id = :categoryId")
    Page<Part> findActiveByCategoryId(UUID categoryId, Pageable pageable);

    @EntityGraph(attributePaths = {"category"})
    @Query("""
        select p from Part p
         where p.deletedAt is null
           and p.category.id = :categoryId
           and exists (
             select 1 from Fitment f
              where f.part.id = p.id
                and f.vehicleVariant.generation.model.make.slug = :makeSlug
                and f.vehicleVariant.generation.model.slug = :modelSlug
                and f.vehicleVariant.year = :year
           )
        """)
    Page<Part> findActiveByCategoryAndMakeModelYear(
        @Param("categoryId") UUID categoryId,
        @Param("makeSlug") String makeSlug,
        @Param("modelSlug") String modelSlug,
        @Param("year") short year,
        Pageable pageable
    );

    /**
     * Parts in a category fitted to one exact vehicle variant (trim + engine).
     * Preferred over the make/model/year query once the buyer has picked a
     * variant, since a year's variants rarely share engine-specific parts.
     */
    @EntityGraph(attributePaths = {"category"})
    @Query("""
        select p from Part p
         where p.deletedAt is null
           and p.category.id = :categoryId
           and exists (
             select 1 from Fitment f
              where f.part.id = p.id
                and f.vehicleVariant.id = :variantId
           )
        """)
    Page<Part> findActiveByCategoryAndVariant(
        @Param("categoryId") UUID categoryId,
        @Param("variantId") UUID variantId,
        Pageable pageable
    );

    @Query("select p from Part p left join fetch p.category where p.id in :ids and p.deletedAt is null")
    List<Part> findAllByIdInWithCategory(@Param("ids") Collection<UUID> ids);

    long countByCategoryIdAndDeletedAtIsNull(UUID categoryId);

    @Query("""
        select p from Part p
         where p.deletedAt is null
           and (:categoryId is null or p.category.id = :categoryId)
           and (
             :q is null or :q = ''
             or lower(p.nameAz) like lower(concat('%', :q, '%'))
             or lower(p.nameRu) like lower(concat('%', :q, '%'))
             or lower(p.nameEn) like lower(concat('%', :q, '%'))
             or lower(coalesce(p.brand, '')) like lower(concat('%', :q, '%'))
           )
        """)
    Page<Part> adminSearch(
        @Param("categoryId") UUID categoryId,
        @Param("q") String q,
        Pageable pageable
    );

    /** Active parts fitted to one exact variant, whatever the category. */
    @EntityGraph(attributePaths = {"category"})
    @Query("""
        select p from Part p
         where p.deletedAt is null
           and exists (
             select 1 from Fitment f
              where f.part.id = p.id
                and f.vehicleVariant.id = :variantId
           )
        """)
    Page<Part> findActiveByVariant(@Param("variantId") UUID variantId, Pageable pageable);

    /** Active parts fitted to any variant of the model year, whatever the category. */
    @EntityGraph(attributePaths = {"category"})
    @Query("""
        select p from Part p
         where p.deletedAt is null
           and exists (
             select 1 from Fitment f
              where f.part.id = p.id
                and f.vehicleVariant.generation.model.make.slug = :makeSlug
                and f.vehicleVariant.generation.model.slug = :modelSlug
                and f.vehicleVariant.year = :year
           )
        """)
    Page<Part> findActiveByMakeModelYear(
        @Param("makeSlug") String makeSlug,
        @Param("modelSlug") String modelSlug,
        @Param("year") short year,
        Pageable pageable
    );

    @EntityGraph(attributePaths = {"category"})
    Page<Part> findAllByDeletedAtIsNull(Pageable pageable);

    /** Active parts per category (the part's own category, no roll-up) fitted to one exact variant. */
    @Query("""
        select p.category.id as categoryId, count(p.id) as partCount
          from Part p
         where p.deletedAt is null
           and exists (
             select 1 from Fitment f
              where f.part.id = p.id
                and f.vehicleVariant.id = :variantId
           )
         group by p.category.id
        """)
    List<CategoryPartCount> countActiveByCategoryForVariant(@Param("variantId") UUID variantId);

    /** Like {@link #countActiveByCategoryForVariant} for any variant of the model year. */
    @Query("""
        select p.category.id as categoryId, count(p.id) as partCount
          from Part p
         where p.deletedAt is null
           and exists (
             select 1 from Fitment f
              where f.part.id = p.id
                and f.vehicleVariant.generation.model.make.slug = :makeSlug
                and f.vehicleVariant.generation.model.slug = :modelSlug
                and f.vehicleVariant.year = :year
           )
         group by p.category.id
        """)
    List<CategoryPartCount> countActiveByCategoryForMakeModelYear(
        @Param("makeSlug") String makeSlug,
        @Param("modelSlug") String modelSlug,
        @Param("year") short year
    );

    /** Active parts per category across the whole catalog. */
    @Query("""
        select p.category.id as categoryId, count(p.id) as partCount
          from Part p
         where p.deletedAt is null
         group by p.category.id
        """)
    List<CategoryPartCount> countActiveByCategory();

    interface CategoryPartCount {
        UUID getCategoryId();
        long getPartCount();
    }
}
