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

import az.autoparts.api.catalog.domain.Part;

public interface PartRepository extends JpaRepository<Part, UUID> {

    @EntityGraph(attributePaths = {"category"})
    Optional<Part> findWithCategoryById(UUID id);

    @Query("select p from Part p where p.deletedAt is null and p.category.id = :categoryId")
    Page<Part> findActiveByCategoryId(UUID categoryId, Pageable pageable);

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
        @org.springframework.data.repository.query.Param("categoryId") UUID categoryId,
        @org.springframework.data.repository.query.Param("makeSlug") String makeSlug,
        @org.springframework.data.repository.query.Param("modelSlug") String modelSlug,
        @org.springframework.data.repository.query.Param("year") short year,
        Pageable pageable
    );

    @Query("select p from Part p left join fetch p.category where p.id in :ids and p.deletedAt is null")
    List<Part> findAllByIdInWithCategory(@org.springframework.data.repository.query.Param("ids") Collection<UUID> ids);

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
        @org.springframework.data.repository.query.Param("categoryId") UUID categoryId,
        @org.springframework.data.repository.query.Param("q") String q,
        Pageable pageable
    );
}
