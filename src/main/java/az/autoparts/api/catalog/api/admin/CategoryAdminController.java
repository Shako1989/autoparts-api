package az.autoparts.api.catalog.api.admin;

import java.util.List;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.catalog.api.admin.dto.AdminCategoryResponse;
import az.autoparts.api.catalog.api.admin.dto.CreateCategoryRequest;
import az.autoparts.api.catalog.api.admin.dto.ReorderCategoriesRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateCategoryRequest;
import az.autoparts.api.catalog.service.CatalogAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/admin/categories")
@PreAuthorize("hasAnyRole('STAFF','ADMIN')")
@RequiredArgsConstructor
public class CategoryAdminController {

    private final CatalogAdminService admin;

    @GetMapping
    public List<AdminCategoryResponse> list() {
        return admin.listCategories();
    }

    @PostMapping
    public AdminCategoryResponse create(@Valid @RequestBody CreateCategoryRequest request) {
        return admin.createCategory(request);
    }

    @PatchMapping("/{id}")
    public AdminCategoryResponse update(@PathVariable UUID id, @Valid @RequestBody UpdateCategoryRequest request) {
        return admin.updateCategory(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        admin.deleteCategory(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/reorder")
    public ResponseEntity<Void> reorder(@Valid @RequestBody ReorderCategoriesRequest request) {
        admin.reorderCategories(request);
        return ResponseEntity.noContent().build();
    }
}
