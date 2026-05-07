package az.autoparts.api.catalog.service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.catalog.api.dto.CategoryDetailResponse;
import az.autoparts.api.catalog.api.dto.CategoryDetailResponse.CategoryBreadcrumb;
import az.autoparts.api.catalog.api.dto.CategoryResponse;
import az.autoparts.api.catalog.api.dto.FitmentResponse;
import az.autoparts.api.catalog.api.dto.PartListItem;
import az.autoparts.api.catalog.api.dto.PartResponse;
import az.autoparts.api.catalog.api.dto.VehicleMakeResponse;
import az.autoparts.api.catalog.api.dto.VehicleModelResponse;
import az.autoparts.api.catalog.api.dto.VehicleVariantResponse;
import az.autoparts.api.common.pagination.PageResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import az.autoparts.api.catalog.api.mapper.CategoryMapper;
import az.autoparts.api.catalog.api.mapper.LocalisedNameSupport;
import az.autoparts.api.catalog.api.mapper.PartMapper;
import az.autoparts.api.catalog.api.mapper.VehicleMapper;
import az.autoparts.api.catalog.domain.Category;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.catalog.domain.VehicleMake;
import az.autoparts.api.catalog.repo.CategoryRepository;
import az.autoparts.api.catalog.repo.FitmentRepository;
import az.autoparts.api.catalog.repo.PartNumberRepository;
import az.autoparts.api.catalog.repo.PartRepository;
import az.autoparts.api.catalog.repo.VehicleMakeRepository;
import az.autoparts.api.catalog.repo.VehicleModelRepository;
import az.autoparts.api.catalog.repo.VehicleVariantRepository;
import az.autoparts.api.common.error.ResourceNotFoundException;
import az.autoparts.api.common.locale.Locale;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
class CatalogServiceImpl implements CatalogService {

    private final VehicleMakeRepository makes;
    private final VehicleModelRepository models;
    private final VehicleVariantRepository variants;
    private final CategoryRepository categories;
    private final PartRepository parts;
    private final PartNumberRepository partNumbers;
    private final FitmentRepository fitments;

    private final VehicleMapper vehicleMapper;
    private final CategoryMapper categoryMapper;
    private final PartMapper partMapper;

    @Override
    public List<VehicleMakeResponse> listMakes() {
        return makes.findAllByOrderByPopularityDescNameAsc().stream()
            .map(vehicleMapper::toMakeResponse)
            .toList();
    }

    @Override
    public List<VehicleModelResponse> listModels(String makeSlug) {
        VehicleMake make = makes.findBySlug(makeSlug)
            .orElseThrow(() -> new ResourceNotFoundException("Vehicle make not found: " + makeSlug));
        return models.findAllByMakeIdOrderByNameAsc(make.getId()).stream()
            .map(vehicleMapper::toModelResponse)
            .toList();
    }

    @Override
    public List<Short> listYears(UUID modelId) {
        if (!models.existsById(modelId)) {
            throw new ResourceNotFoundException("Vehicle model not found: " + modelId);
        }
        return variants.findDistinctYearsByModelId(modelId);
    }

    @Override
    public List<VehicleVariantResponse> listVariants(UUID modelId, short year) {
        if (!models.existsById(modelId)) {
            throw new ResourceNotFoundException("Vehicle model not found: " + modelId);
        }
        return variants.findAllByModelIdAndYearOrderByTrimAsc(modelId, year).stream()
            .map(vehicleMapper::toVariantResponse)
            .toList();
    }

    @Override
    public List<CategoryResponse> getCategoryTree(Locale locale) {
        List<Category> all = categories.findAllByOrderBySortOrderAscNameAzAsc();
        Map<UUID, List<Category>> byParent = new HashMap<>();
        for (Category c : all) {
            UUID parentId = c.getParent() == null ? null : c.getParent().getId();
            byParent.computeIfAbsent(parentId, k -> new ArrayList<>()).add(c);
        }
        return buildSubtree(byParent.get(null), byParent, locale);
    }

    private List<CategoryResponse> buildSubtree(
        List<Category> nodes, Map<UUID, List<Category>> byParent, Locale locale
    ) {
        if (nodes == null) return List.of();
        List<CategoryResponse> out = new ArrayList<>(nodes.size());
        for (Category n : nodes) {
            List<CategoryResponse> children = buildSubtree(byParent.get(n.getId()), byParent, locale);
            out.add(categoryMapper.toResponseWithChildren(n, children, locale));
        }
        return out;
    }

    @Override
    public CategoryDetailResponse getCategoryBySlug(String slug, Locale locale) {
        Category category = categories.findBySlug(slug)
            .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + slug));

        List<Category> directChildren = categories.findAllByParentIdOrderBySortOrderAsc(category.getId());
        List<CategoryResponse> children = directChildren.stream()
            .map(c -> categoryMapper.toResponseWithChildren(c, List.of(), locale))
            .toList();

        List<CategoryBreadcrumb> breadcrumbs = breadcrumbsFor(category, locale);

        return new CategoryDetailResponse(
            category.getId(),
            category.getParent() == null ? null : category.getParent().getId(),
            category.getSlug(),
            LocalisedNameSupport.name(category, locale),
            category.getIconUrl(),
            category.getSortOrder(),
            children,
            breadcrumbs
        );
    }

    private List<CategoryBreadcrumb> breadcrumbsFor(Category leaf, Locale locale) {
        List<CategoryBreadcrumb> trail = new ArrayList<>();
        Category cursor = leaf;
        while (cursor != null) {
            trail.add(0, new CategoryBreadcrumb(
                cursor.getId(), cursor.getSlug(), LocalisedNameSupport.name(cursor, locale)));
            cursor = cursor.getParent();
        }
        return trail;
    }

    @Override
    public PageResponse<PartListItem> listPartsInCategory(String slug, int page, int size, Locale locale) {
        Category category = categories.findBySlug(slug)
            .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + slug));

        int safePage = Math.max(0, page);
        int safeSize = Math.min(100, Math.max(1, size));

        Page<Part> result = parts.findActiveByCategoryId(
            category.getId(),
            PageRequest.of(safePage, safeSize, Sort.by("createdAt").descending())
        );
        return PageResponse.of(result).map(p -> partMapper.toListItem(p, locale));
    }

    @Override
    public PartResponse getPart(UUID partId, Locale locale) {
        Part part = parts.findWithCategoryById(partId)
            .orElseThrow(() -> new ResourceNotFoundException("Part not found: " + partId));
        return partMapper.toResponse(part, partNumbers.findAllByPartId(partId), locale);
    }

    @Override
    public List<FitmentResponse> getPartFitments(UUID partId) {
        if (!parts.existsById(partId)) {
            throw new ResourceNotFoundException("Part not found: " + partId);
        }
        return fitments.findAllByPartId(partId).stream()
            .map(partMapper::toFitmentResponse)
            .toList();
    }
}
