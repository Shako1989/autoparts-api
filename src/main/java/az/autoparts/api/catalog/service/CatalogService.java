package az.autoparts.api.catalog.service;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import az.autoparts.api.catalog.api.dto.CategoryDetailResponse;
import az.autoparts.api.catalog.api.dto.CategoryResponse;
import az.autoparts.api.catalog.api.dto.DiagramResponse;
import az.autoparts.api.catalog.api.dto.FitmentResponse;
import az.autoparts.api.catalog.api.dto.PartListItem;
import az.autoparts.api.catalog.api.dto.PartResponse;
import az.autoparts.api.catalog.api.dto.PartSummary;
import az.autoparts.api.catalog.api.dto.VehicleMakeResponse;
import az.autoparts.api.catalog.api.dto.VehicleModelResponse;
import az.autoparts.api.catalog.api.dto.VehicleVariantResponse;
import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.pagination.PageResponse;

/**
 * Public read API of the catalog module. Other modules (search, listings, ...)
 * call this; they must never reach into catalog.repo or catalog.domain directly.
 */
public interface CatalogService {

    List<VehicleMakeResponse> listMakes();

    List<VehicleModelResponse> listModels(String makeSlug);

    List<Short> listYears(UUID modelId);

    List<VehicleVariantResponse> listVariants(UUID modelId, short year);

    List<CategoryResponse> getCategoryTree(Locale locale);

    CategoryDetailResponse getCategoryBySlug(String slug, Locale locale);

    PageResponse<PartListItem> listPartsInCategory(String slug, int page, int size, Locale locale);

    PartResponse getPart(UUID partId, Locale locale);

    /**
     * Returns whether a part exists (non-deleted). Used by other modules
     * (e.g. listings) to validate references without loading the full entity.
     */
    boolean partExists(UUID partId);

    /**
     * Batch-fetches minimal part info for many parts. Used by search and listings
     * to enrich results without N+1.
     */
    Map<UUID, PartSummary> getPartsSummary(Collection<UUID> partIds, Locale locale);

    List<FitmentResponse> getPartFitments(UUID partId);

    DiagramResponse getDiagramBySlug(String slug, Locale locale);

    List<DiagramResponse> getCategoryDiagrams(String slug, Locale locale);
}
