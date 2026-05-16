package az.autoparts.api.catalog.service;

import java.util.List;
import java.util.UUID;

import az.autoparts.api.catalog.api.dto.CategoryDetailResponse;
import az.autoparts.api.catalog.api.dto.CategoryResponse;
import az.autoparts.api.catalog.api.dto.DiagramResponse;
import az.autoparts.api.catalog.api.dto.FitmentResponse;
import az.autoparts.api.catalog.api.dto.PartListItem;
import az.autoparts.api.catalog.api.dto.PartResponse;
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

    List<FitmentResponse> getPartFitments(UUID partId);

    DiagramResponse getDiagramBySlug(String slug, Locale locale);

    List<DiagramResponse> getCategoryDiagrams(String slug, Locale locale);
}
