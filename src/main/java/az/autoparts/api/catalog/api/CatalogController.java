package az.autoparts.api.catalog.api;

import java.util.List;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.catalog.api.dto.CategoryDetailResponse;
import az.autoparts.api.catalog.api.dto.CategoryResponse;
import az.autoparts.api.catalog.api.dto.DiagramResponse;
import az.autoparts.api.catalog.api.dto.FitmentResponse;
import az.autoparts.api.catalog.api.dto.PartListItem;
import az.autoparts.api.catalog.api.dto.PartResponse;
import az.autoparts.api.catalog.api.dto.VehicleMakeResponse;
import az.autoparts.api.catalog.api.dto.VehicleModelResponse;
import az.autoparts.api.catalog.api.dto.VehicleVariantResponse;
import az.autoparts.api.catalog.service.CatalogService;
import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.pagination.PageResponse;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/catalog")
@RequiredArgsConstructor
public class CatalogController {

    private final CatalogService catalogService;

    @GetMapping("/makes")
    public List<VehicleMakeResponse> listMakes() {
        return catalogService.listMakes();
    }

    @GetMapping("/makes/{makeSlug}/models")
    public List<VehicleModelResponse> listModels(@PathVariable String makeSlug) {
        return catalogService.listModels(makeSlug);
    }

    @GetMapping("/models/{modelId}/years")
    public List<Short> listYears(@PathVariable UUID modelId) {
        return catalogService.listYears(modelId);
    }

    @GetMapping("/variants")
    public List<VehicleVariantResponse> listVariants(
        @RequestParam("model") UUID modelId,
        @RequestParam("year") short year
    ) {
        return catalogService.listVariants(modelId, year);
    }

    @GetMapping("/categories")
    public List<CategoryResponse> getCategoryTree(
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return catalogService.getCategoryTree(Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @GetMapping("/categories/{slug}")
    public CategoryDetailResponse getCategory(
        @PathVariable String slug,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return catalogService.getCategoryBySlug(slug, Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @GetMapping("/categories/{slug}/parts")
    public PageResponse<PartListItem> listPartsInCategory(
        @PathVariable String slug,
        @RequestParam(name = "make", required = false) String makeSlug,
        @RequestParam(name = "model", required = false) String modelSlug,
        @RequestParam(name = "year", required = false) Short year,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return catalogService.listPartsInCategory(
            slug, makeSlug, modelSlug, year, page, size, Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @GetMapping("/parts/{partId}")
    public PartResponse getPart(
        @PathVariable UUID partId,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return catalogService.getPart(partId, Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @GetMapping("/parts/{partId}/fitments")
    public List<FitmentResponse> getPartFitments(@PathVariable UUID partId) {
        return catalogService.getPartFitments(partId);

    }

    @GetMapping("/diagrams/{slug}")
    public DiagramResponse getDiagram(
        @PathVariable String slug,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return catalogService.getDiagramBySlug(slug, Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @GetMapping("/categories/{slug}/diagrams")
    public List<DiagramResponse> getCategoryDiagrams(
        @PathVariable String slug,
        @RequestParam(name = "make", required = false) String makeSlug,
        @RequestParam(name = "model", required = false) String modelSlug,
        @RequestParam(name = "year", required = false) Short year,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return catalogService.getCategoryDiagrams(
            slug, makeSlug, modelSlug, year, Locale.fromHeaderOrDefault(acceptLanguage));
    }
}
