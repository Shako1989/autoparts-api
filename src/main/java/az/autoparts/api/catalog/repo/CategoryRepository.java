package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.Category;

public interface CategoryRepository extends JpaRepository<Category, UUID> {

    Optional<Category> findBySlug(String slug);

    List<Category> findAllByOrderBySortOrderAscNameAzAsc();

    List<Category> findAllByParentIdOrderBySortOrderAsc(UUID parentId);

    List<Category> findAllByParentIsNullOrderBySortOrderAsc();
}
