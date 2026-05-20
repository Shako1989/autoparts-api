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

    @Query("select p from Part p left join fetch p.category where p.id in :ids and p.deletedAt is null")
    List<Part> findAllByIdInWithCategory(@org.springframework.data.repository.query.Param("ids") Collection<UUID> ids);
}
