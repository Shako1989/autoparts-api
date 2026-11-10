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

    /**
     * Parts in a category, optionally narrowed to a vehicle. {@code variantId}
     * (an exact trim + engine) wins over the make/model/year triple when both
     * are given; the triple alone matches any variant of that model year.
     */
    PageResponse<PartListItem> listPartsInCategory(
        String slug, String makeSlug, String modelSlug, Short year, UUID variantId,
        int page, int size, Locale locale);

    /**
     * Parts that fit a vehicle in any category, newest first, with the same
     * vehicle filter rules as {@link #listPartsInCategory}; without a vehicle
     * filter, every active part.
     */
    PageResponse<PartListItem> listPartsForVehicle(
        String makeSlug, String modelSlug, Short year, UUID variantId,
        int page, int size, Locale locale);

    /**
     * Active parts per category for a vehicle, rolled up to every ancestor,
     * so a root's count is the number of parts anywhere under it. Categories
     * without parts are absent. Same vehicle filter rules as
     * {@link #listPartsInCategory}; without a filter, the whole catalog.
     */
    Map<UUID, Long> countPartsByCategory(String makeSlug, String modelSlug, Short year, UUID variantId);

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

    /** Diagrams in a category, narrowed like {@link #listPartsInCategory}. */
    List<DiagramResponse> getCategoryDiagrams(
        String slug, String makeSlug, String modelSlug, Short year, UUID variantId, Locale locale);
}
