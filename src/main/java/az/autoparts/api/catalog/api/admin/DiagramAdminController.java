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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.catalog.api.admin.dto.AdminCalloutEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminDiagramListItem;
import az.autoparts.api.catalog.api.admin.dto.AdminDiagramResponse;
import az.autoparts.api.catalog.api.admin.dto.CreateCalloutRequest;
import az.autoparts.api.catalog.api.admin.dto.CreateDiagramRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateCalloutRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateDiagramRequest;
import az.autoparts.api.catalog.service.CatalogAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/admin/diagrams")
@PreAuthorize("hasAnyRole('STAFF','ADMIN')")
@RequiredArgsConstructor
public class DiagramAdminController {

    private final CatalogAdminService admin;

    @GetMapping
    public List<AdminDiagramListItem> list(
        @RequestParam(name = "category", required = false) UUID categoryId
    ) {
        return admin.listDiagrams(categoryId);
    }

    @GetMapping("/{id}")
    public AdminDiagramResponse get(@PathVariable UUID id) {
        return admin.getDiagram(id);
    }

    @PostMapping
    public AdminDiagramResponse create(@Valid @RequestBody CreateDiagramRequest request) {
        return admin.createDiagram(request);
    }

    @PatchMapping("/{id}")
    public AdminDiagramResponse update(@PathVariable UUID id, @Valid @RequestBody UpdateDiagramRequest request) {
        return admin.updateDiagram(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        admin.deleteDiagram(id);
        return ResponseEntity.noContent().build();
    }

    // ---------- callouts ----------

    @PostMapping("/{id}/callouts")
    public AdminCalloutEntry addCallout(@PathVariable UUID id, @Valid @RequestBody CreateCalloutRequest request) {
        return admin.addCallout(id, request);
    }

    @PatchMapping("/{id}/callouts/{calloutId}")
    public AdminCalloutEntry updateCallout(
        @PathVariable UUID id,
        @PathVariable UUID calloutId,
        @Valid @RequestBody UpdateCalloutRequest request
    ) {
        return admin.updateCallout(id, calloutId, request);
    }

    @DeleteMapping("/{id}/callouts/{calloutId}")
    public ResponseEntity<Void> removeCallout(@PathVariable UUID id, @PathVariable UUID calloutId) {
        admin.removeCallout(id, calloutId);
        return ResponseEntity.noContent().build();
    }
}
