package az.autoparts.api.catalog.service;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import az.autoparts.api.catalog.api.dto.CategoryDetailResponse;
import az.autoparts.api.catalog.api.dto.CategoryResponse;
import az.autoparts.api.catalog.api.dto.DiagramResponse;
import az.autoparts.api.catalog.api.dto.FitmentInput;
import az.autoparts.api.catalog.api.dto.FitmentResponse;
import az.autoparts.api.catalog.api.dto.PartListItem;
import az.autoparts.api.catalog.api.dto.PartResponse;
import az.autoparts.api.catalog.api.dto.PartSummary;
import az.autoparts.api.catalog.api.dto.VehicleGenerationResponse;
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

    /** Generations for a model. Each model has at least one default generation. */
    List<VehicleGenerationResponse> listGenerations(UUID modelId);

    /** Aggregated years across all generations of a model (legacy aggregator). */
    List<Short> listYears(UUID modelId);

    /** Years for a specific generation. Preferred over listYears(modelId). */
    List<Short> listYearsByGeneration(UUID generationId);

    /** Variants across all generations of a model for a given year (legacy). */
    List<VehicleVariantResponse> listVariants(UUID modelId, short year);

    /** Variants for a specific generation + year. Preferred. */
    List<VehicleVariantResponse> listVariantsByGeneration(UUID generationId, short year);

    List<CategoryResponse> getCategoryTree(Locale locale);

    CategoryDetailResponse getCategoryBySlug(String slug, Locale locale);

    PageResponse<PartListItem> listPartsInCategory(
        String slug, String makeSlug, String modelSlug, Short year, int page, int size, Locale locale);

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

    /**
     * Idempotently attaches fitments to a catalog part. Each input expands to
     * all variants matching (makeSlug, modelSlug, year); a fitment row is
     * inserted only if one doesn't already exist for that (part, variant) pair.
     * Returns the number of newly-created fitment rows.
     */
    int addFitments(UUID partId, List<FitmentInput> fitments);

    DiagramResponse getDiagramBySlug(String slug, Locale locale);

    List<DiagramResponse> getCategoryDiagrams(
        String slug, String makeSlug, String modelSlug, Short year, Locale locale);
}
