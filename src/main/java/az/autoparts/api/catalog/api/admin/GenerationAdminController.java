package az.autoparts.api.catalog.api.admin;

import java.net.URI;
import java.util.List;
import java.util.Map;
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

import az.autoparts.api.catalog.api.admin.dto.AdminGenerationResponse;
import az.autoparts.api.catalog.api.admin.dto.CreateGenerationRequest;
import az.autoparts.api.catalog.api.admin.dto.MoveVariantsRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateGenerationRequest;
import az.autoparts.api.catalog.service.CatalogAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/admin/catalog")
@PreAuthorize("hasAnyRole('STAFF','ADMIN')")
@RequiredArgsConstructor
public class GenerationAdminController {

    private final CatalogAdminService admin;

    @GetMapping("/models/{modelId}/generations")
    public List<AdminGenerationResponse> list(@PathVariable UUID modelId) {
        return admin.listGenerationsForAdmin(modelId);
    }

    @PostMapping("/models/{modelId}/generations")
    public ResponseEntity<AdminGenerationResponse> create(
            @PathVariable UUID modelId,
            @Valid @RequestBody CreateGenerationRequest request) {
        AdminGenerationResponse created = admin.createGeneration(modelId, request);
        return ResponseEntity
            .created(URI.create("/api/v1/admin/catalog/generations/" + created.id()))
            .body(created);
    }

    @PatchMapping("/generations/{generationId}")
    public AdminGenerationResponse update(
            @PathVariable UUID generationId,
            @Valid @RequestBody UpdateGenerationRequest request) {
        return admin.updateGeneration(generationId, request);
    }

    @DeleteMapping("/generations/{generationId}")
    public ResponseEntity<Void> delete(@PathVariable UUID generationId) {
        admin.deleteGeneration(generationId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/generations/{srcGenerationId}/move-variants")
    public Map<String, Integer> moveVariants(
            @PathVariable UUID srcGenerationId,
            @Valid @RequestBody MoveVariantsRequest request) {
        int moved = admin.moveVariants(srcGenerationId, request);
        return Map.of("moved", moved);
    }
}
