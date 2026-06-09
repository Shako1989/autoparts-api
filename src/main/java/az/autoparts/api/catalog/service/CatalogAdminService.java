package az.autoparts.api.catalog.service;

import java.util.List;
import java.util.UUID;

import az.autoparts.api.catalog.api.admin.dto.AdminCalloutEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminCategoryResponse;
import az.autoparts.api.catalog.api.admin.dto.AdminDiagramListItem;
import az.autoparts.api.catalog.api.admin.dto.AdminDiagramResponse;
import az.autoparts.api.catalog.api.admin.dto.AdminFitmentEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminPartListItem;
import az.autoparts.api.catalog.api.admin.dto.AdminPartNumberEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminPartResponse;
import az.autoparts.api.catalog.api.admin.dto.AdminPresignedUploadResponse;
import az.autoparts.api.catalog.api.admin.dto.CreateCalloutRequest;
import az.autoparts.api.catalog.api.admin.dto.CreateCategoryRequest;
import az.autoparts.api.catalog.api.admin.dto.CreateDiagramRequest;
import az.autoparts.api.catalog.api.admin.dto.CreatePartNumberRequest;
import az.autoparts.api.catalog.api.admin.dto.CreatePartRequest;
import az.autoparts.api.catalog.api.admin.dto.ReorderCategoriesRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateCalloutRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateCategoryRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateDiagramRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdatePartRequest;
import az.autoparts.api.catalog.api.dto.FitmentInput;
import az.autoparts.api.common.pagination.PageResponse;

/**
 * Admin-only write API for the catalog. Lives inside the catalog module and
 * uses catalog repositories directly. Public-read consumers (search, listings,
 * buyer UI) call {@link CatalogService} instead — admin and read APIs are
 * intentionally separate so role-gated mutations don't pollute the read shape.
 */
public interface CatalogAdminService {

    // ---------- categories ----------
    List<AdminCategoryResponse> listCategories();

    AdminCategoryResponse createCategory(CreateCategoryRequest request);

    AdminCategoryResponse updateCategory(UUID id, UpdateCategoryRequest request);

    void deleteCategory(UUID id);

    void reorderCategories(ReorderCategoriesRequest request);

    // ---------- parts ----------
    PageResponse<AdminPartListItem> listParts(UUID categoryId, String q, int page, int size);

    AdminPartResponse getPart(UUID partId);

    AdminPartResponse createPart(CreatePartRequest request);

    AdminPartResponse updatePart(UUID partId, UpdatePartRequest request);

    void deletePart(UUID partId);

    // ---------- part numbers ----------
    AdminPartNumberEntry addPartNumber(UUID partId, CreatePartNumberRequest request);

    void removePartNumber(UUID partId, UUID partNumberId);

    // ---------- fitments ----------
    /** Idempotently attaches fitments; delegates to {@link CatalogService#addFitments}. */
    int addFitmentsToPart(UUID partId, List<FitmentInput> fitments);

    AdminFitmentEntry getFitment(UUID partId, UUID fitmentId);

    void removeFitment(UUID partId, UUID fitmentId);

    // ---------- diagrams ----------
    List<AdminDiagramListItem> listDiagrams(UUID categoryId);

    AdminDiagramResponse getDiagram(UUID diagramId);

    AdminDiagramResponse createDiagram(CreateDiagramRequest request);

    AdminDiagramResponse updateDiagram(UUID diagramId, UpdateDiagramRequest request);

    void deleteDiagram(UUID diagramId);

    AdminCalloutEntry addCallout(UUID diagramId, CreateCalloutRequest request);

    AdminCalloutEntry updateCallout(UUID diagramId, UUID calloutId, UpdateCalloutRequest request);

    void removeCallout(UUID diagramId, UUID calloutId);

    // ---------- uploads ----------
    /**
     * Returns a presigned PUT URL for uploading a catalog image (category icon
     * or part image) directly from the browser to MinIO. The caller stores the
     * returned publicUrl on the entity once the upload completes.
     */
    AdminPresignedUploadResponse presignCatalogImageUpload(String contentType);
}
