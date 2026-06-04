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

import az.autoparts.api.catalog.api.admin.dto.AdminPartListItem;
import az.autoparts.api.catalog.api.admin.dto.AdminPartNumberEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminPartResponse;
import az.autoparts.api.catalog.api.admin.dto.CreatePartNumberRequest;
import az.autoparts.api.catalog.api.admin.dto.CreatePartRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdatePartRequest;
import az.autoparts.api.catalog.api.dto.FitmentInput;
import az.autoparts.api.catalog.service.CatalogAdminService;
import az.autoparts.api.common.pagination.PageResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/admin/parts")
@PreAuthorize("hasAnyRole('STAFF','ADMIN')")
@RequiredArgsConstructor
public class PartAdminController {

    private final CatalogAdminService admin;

    @GetMapping
    public PageResponse<AdminPartListItem> list(
        @RequestParam(name = "category", required = false) UUID categoryId,
        @RequestParam(name = "q", defaultValue = "") String q,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        return admin.listParts(categoryId, q, page, size);
    }

    @GetMapping("/{id}")
    public AdminPartResponse get(@PathVariable UUID id) {
        return admin.getPart(id);
    }

    @PostMapping
    public AdminPartResponse create(@Valid @RequestBody CreatePartRequest request) {
        return admin.createPart(request);
    }

    @PatchMapping("/{id}")
    public AdminPartResponse update(@PathVariable UUID id, @Valid @RequestBody UpdatePartRequest request) {
        return admin.updatePart(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        admin.deletePart(id);
        return ResponseEntity.noContent().build();
    }

    // ---------- part numbers ----------

    @PostMapping("/{id}/numbers")
    public AdminPartNumberEntry addPartNumber(
        @PathVariable UUID id, @Valid @RequestBody CreatePartNumberRequest request
    ) {
        return admin.addPartNumber(id, request);
    }

    @DeleteMapping("/{id}/numbers/{numberId}")
    public ResponseEntity<Void> removePartNumber(@PathVariable UUID id, @PathVariable UUID numberId) {
        admin.removePartNumber(id, numberId);
        return ResponseEntity.noContent().build();
    }

    // ---------- fitments ----------

    public record AddFitmentsRequest(@Valid List<FitmentInput> fitments) {}

    public record AddFitmentsResponse(int added) {}

    @PostMapping("/{id}/fitments")
    public AddFitmentsResponse addFitments(@PathVariable UUID id, @Valid @RequestBody AddFitmentsRequest request) {
        int added = admin.addFitmentsToPart(id, request.fitments() == null ? List.of() : request.fitments());
        return new AddFitmentsResponse(added);
    }

    @DeleteMapping("/{id}/fitments/{fitmentId}")
    public ResponseEntity<Void> removeFitment(@PathVariable UUID id, @PathVariable UUID fitmentId) {
        admin.removeFitment(id, fitmentId);
        return ResponseEntity.noContent().build();
    }
}
