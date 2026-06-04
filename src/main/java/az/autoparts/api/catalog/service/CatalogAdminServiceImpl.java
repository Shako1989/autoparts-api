package az.autoparts.api.catalog.service;

import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.catalog.api.admin.dto.AdminCategoryResponse;
import az.autoparts.api.catalog.api.admin.dto.AdminFitmentEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminPartListItem;
import az.autoparts.api.catalog.api.admin.dto.AdminPartNumberEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminPartResponse;
import az.autoparts.api.catalog.api.admin.dto.CreateCategoryRequest;
import az.autoparts.api.catalog.api.admin.dto.CreatePartNumberRequest;
import az.autoparts.api.catalog.api.admin.dto.CreatePartRequest;
import az.autoparts.api.catalog.api.admin.dto.ReorderCategoriesRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdateCategoryRequest;
import az.autoparts.api.catalog.api.admin.dto.UpdatePartRequest;
import az.autoparts.api.catalog.api.dto.FitmentInput;
import az.autoparts.api.catalog.domain.Category;
import az.autoparts.api.catalog.domain.Fitment;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.catalog.domain.PartNumber;
import az.autoparts.api.catalog.repo.CategoryRepository;
import az.autoparts.api.catalog.repo.FitmentRepository;
import az.autoparts.api.catalog.repo.PartNumberRepository;
import az.autoparts.api.catalog.repo.PartRepository;
import az.autoparts.api.common.error.BadRequestException;
import az.autoparts.api.common.error.ResourceNotFoundException;
import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.listings.service.ListingService;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class CatalogAdminServiceImpl implements CatalogAdminService {

    private final CategoryRepository categories;
    private final PartRepository parts;
    private final PartNumberRepository partNumbers;
    private final FitmentRepository fitments;
    private final CatalogService catalogService;
    private final ListingService listingService;

    // ---------- categories ----------

    @Override
    @Transactional(readOnly = true)
    public List<AdminCategoryResponse> listCategories() {
        List<Category> all = categories.findAllByOrderBySortOrderAscNameAzAsc();
        Map<UUID, Long> childCounts = all.stream()
            .filter(c -> c.getParent() != null)
            .collect(Collectors.groupingBy(c -> c.getParent().getId(), Collectors.counting()));
        return all.stream()
            .map(c -> new AdminCategoryResponse(
                c.getId(),
                c.getParent() == null ? null : c.getParent().getId(),
                c.getSlug(),
                c.getNameAz(),
                c.getNameRu(),
                c.getNameEn(),
                c.getIconUrl(),
                c.getSortOrder(),
                childCounts.getOrDefault(c.getId(), 0L),
                parts.countByCategoryIdAndDeletedAtIsNull(c.getId())
            ))
            .toList();
    }

    @Override
    @Transactional
    public AdminCategoryResponse createCategory(CreateCategoryRequest request) {
        if (categories.existsBySlug(request.slug())) {
            throw new BadRequestException("Category slug already exists: " + request.slug());
        }
        Category parent = null;
        if (request.parentId() != null) {
            parent = categories.findById(request.parentId())
                .orElseThrow(() -> new ResourceNotFoundException("Parent category not found: " + request.parentId()));
        }
        Category saved = categories.save(Category.builder()
            .slug(request.slug())
            .parent(parent)
            .nameAz(request.nameAz())
            .nameRu(request.nameRu())
            .nameEn(request.nameEn())
            .iconUrl(request.iconUrl())
            .sortOrder(request.sortOrder() == null ? 0 : request.sortOrder())
            .build());
        return toCategoryResponse(saved);
    }

    @Override
    @Transactional
    public AdminCategoryResponse updateCategory(UUID id, UpdateCategoryRequest request) {
        Category category = categories.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + id));
        if (request.nameAz() != null && !request.nameAz().isBlank()) category.setNameAz(request.nameAz());
        if (request.nameRu() != null && !request.nameRu().isBlank()) category.setNameRu(request.nameRu());
        if (request.nameEn() != null && !request.nameEn().isBlank()) category.setNameEn(request.nameEn());
        if (request.iconUrl() != null) category.setIconUrl(request.iconUrl().isBlank() ? null : request.iconUrl());
        if (request.sortOrder() != null) category.setSortOrder(request.sortOrder());
        if (request.parentId() != null) {
            if (request.parentId().equals(category.getId())) {
                throw new BadRequestException("Category cannot be its own parent");
            }
            Category newParent = categories.findById(request.parentId())
                .orElseThrow(() -> new ResourceNotFoundException("Parent category not found: " + request.parentId()));
            ensureNoCycle(category, newParent);
            category.setParent(newParent);
        }
        return toCategoryResponse(categories.save(category));
    }

    @Override
    @Transactional
    public void deleteCategory(UUID id) {
        Category category = categories.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + id));
        long childCount = categories.countByParentId(id);
        long partCount = parts.countByCategoryIdAndDeletedAtIsNull(id);
        if (childCount > 0 || partCount > 0) {
            throw new BadRequestException(
                "Category has " + childCount + " subcategories and " + partCount
                    + " parts. Move or delete them first.");
        }
        categories.delete(category);
    }

    @Override
    @Transactional
    public void reorderCategories(ReorderCategoriesRequest request) {
        for (ReorderCategoriesRequest.Entry e : request.entries()) {
            Category c = categories.findById(e.id())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + e.id()));
            c.setSortOrder(e.sortOrder());
            categories.save(c);
        }
    }

    private void ensureNoCycle(Category target, Category newParent) {
        Category cursor = newParent;
        while (cursor != null) {
            if (cursor.getId().equals(target.getId())) {
                throw new BadRequestException("Cannot move category under its own descendant");
            }
            cursor = cursor.getParent();
        }
    }

    private AdminCategoryResponse toCategoryResponse(Category c) {
        return new AdminCategoryResponse(
            c.getId(),
            c.getParent() == null ? null : c.getParent().getId(),
            c.getSlug(),
            c.getNameAz(),
            c.getNameRu(),
            c.getNameEn(),
            c.getIconUrl(),
            c.getSortOrder(),
            categories.countByParentId(c.getId()),
            parts.countByCategoryIdAndDeletedAtIsNull(c.getId())
        );
    }

    // ---------- parts ----------

    @Override
    @Transactional(readOnly = true)
    public PageResponse<AdminPartListItem> listParts(UUID categoryId, String q, int page, int size) {
        int safePage = Math.max(0, page);
        int safeSize = Math.min(100, Math.max(1, size));
        Page<Part> result = parts.adminSearch(
            categoryId,
            q == null ? "" : q.trim(),
            PageRequest.of(safePage, safeSize, Sort.by("createdAt").descending())
        );

        List<UUID> partIds = result.getContent().stream().map(Part::getId).toList();
        Map<UUID, LinkedHashSet<String>> dedupedFits = buildDedupedFits(partIds);

        return PageResponse.of(result).map(p -> {
            LinkedHashSet<String> all = dedupedFits.getOrDefault(p.getId(), new LinkedHashSet<>());
            List<String> topThree = all.stream().limit(3).toList();
            return new AdminPartListItem(
                p.getId(),
                p.getCategory().getId(),
                p.getCategory().getSlug(),
                p.getNameEn(),
                p.getBrand(),
                p.getDefaultImageUrl(),
                topThree,
                all.size()
            );
        });
    }

    private Map<UUID, LinkedHashSet<String>> buildDedupedFits(List<UUID> partIds) {
        if (partIds.isEmpty()) return Map.of();
        Map<UUID, LinkedHashSet<String>> deduped = new HashMap<>();
        for (Fitment f : fitments.findAllByPartIdIn(partIds)) {
            var v = f.getVehicleVariant();
            String label = v.getModel().getMake().getName() + " "
                + v.getModel().getName() + " "
                + v.getYear();
            deduped.computeIfAbsent(f.getPart().getId(), k -> new LinkedHashSet<>()).add(label);
        }
        return deduped;
    }

    @Override
    @Transactional(readOnly = true)
    public AdminPartResponse getPart(UUID partId) {
        Part part = parts.findWithCategoryById(partId)
            .orElseThrow(() -> new ResourceNotFoundException("Part not found: " + partId));
        return toPartResponse(part);
    }

    @Override
    @Transactional
    public AdminPartResponse createPart(CreatePartRequest request) {
        Category category = categories.findById(request.categoryId())
            .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + request.categoryId()));
        Part saved = parts.save(Part.builder()
            .category(category)
            .nameAz(request.nameAz())
            .nameRu(request.nameRu())
            .nameEn(request.nameEn())
            .brand(blankToNull(request.brand()))
            .description(blankToNull(request.description()))
            .defaultImageUrl(blankToNull(request.defaultImageUrl()))
            .build());
        return toPartResponse(saved);
    }

    @Override
    @Transactional
    public AdminPartResponse updatePart(UUID partId, UpdatePartRequest request) {
        Part part = parts.findWithCategoryById(partId)
            .orElseThrow(() -> new ResourceNotFoundException("Part not found: " + partId));
        if (request.categoryId() != null && !request.categoryId().equals(part.getCategory().getId())) {
            Category category = categories.findById(request.categoryId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + request.categoryId()));
            part.setCategory(category);
        }
        if (request.nameAz() != null && !request.nameAz().isBlank()) part.setNameAz(request.nameAz());
        if (request.nameRu() != null && !request.nameRu().isBlank()) part.setNameRu(request.nameRu());
        if (request.nameEn() != null && !request.nameEn().isBlank()) part.setNameEn(request.nameEn());
        if (request.brand() != null) part.setBrand(blankToNull(request.brand()));
        if (request.description() != null) part.setDescription(blankToNull(request.description()));
        if (request.defaultImageUrl() != null) part.setDefaultImageUrl(blankToNull(request.defaultImageUrl()));
        return toPartResponse(parts.save(part));
    }

    @Override
    @Transactional
    public void deletePart(UUID partId) {
        Part part = parts.findById(partId)
            .orElseThrow(() -> new ResourceNotFoundException("Part not found: " + partId));
        if (listingService.hasActiveListingsForPart(partId)) {
            throw new BadRequestException(
                "Part is referenced by active listings. Pause those listings before deleting.");
        }
        parts.delete(part);
    }

    // ---------- part numbers ----------

    @Override
    @Transactional
    public AdminPartNumberEntry addPartNumber(UUID partId, CreatePartNumberRequest request) {
        Part part = parts.findById(partId)
            .orElseThrow(() -> new ResourceNotFoundException("Part not found: " + partId));
        String normalized = request.number().replaceAll("\\s+", "");
        boolean exists = partNumbers.findAllByPartId(partId).stream()
            .anyMatch(pn -> pn.getNumber().equalsIgnoreCase(normalized) && pn.getType() == request.type());
        if (exists) {
            throw new BadRequestException("This part already has that " + request.type() + " number");
        }
        PartNumber saved = partNumbers.save(PartNumber.builder()
            .part(part)
            .number(normalized)
            .type(request.type())
            .source(blankToNull(request.source()))
            .build());
        return new AdminPartNumberEntry(saved.getId(), saved.getNumber(), saved.getType(), saved.getSource());
    }

    @Override
    @Transactional
    public void removePartNumber(UUID partId, UUID partNumberId) {
        PartNumber pn = partNumbers.findById(partNumberId)
            .orElseThrow(() -> new ResourceNotFoundException("Part number not found: " + partNumberId));
        if (!pn.getPart().getId().equals(partId)) {
            throw new ResourceNotFoundException("Part number does not belong to part: " + partId);
        }
        partNumbers.delete(pn);
    }

    // ---------- fitments ----------

    @Override
    public int addFitmentsToPart(UUID partId, List<FitmentInput> input) {
        return catalogService.addFitments(partId, input);
    }

    @Override
    @Transactional(readOnly = true)
    public AdminFitmentEntry getFitment(UUID partId, UUID fitmentId) {
        Fitment f = loadOwnedFitment(partId, fitmentId);
        return toFitmentEntry(f);
    }

    @Override
    @Transactional
    public void removeFitment(UUID partId, UUID fitmentId) {
        Fitment f = loadOwnedFitment(partId, fitmentId);
        fitments.delete(f);
    }

    private Fitment loadOwnedFitment(UUID partId, UUID fitmentId) {
        Fitment f = fitments.findById(fitmentId)
            .orElseThrow(() -> new ResourceNotFoundException("Fitment not found: " + fitmentId));
        if (!f.getPart().getId().equals(partId)) {
            throw new ResourceNotFoundException("Fitment does not belong to part: " + partId);
        }
        return f;
    }

    // ---------- helpers ----------

    private AdminPartResponse toPartResponse(Part part) {
        List<AdminPartNumberEntry> numberEntries = partNumbers.findAllByPartId(part.getId()).stream()
            .map(n -> new AdminPartNumberEntry(n.getId(), n.getNumber(), n.getType(), n.getSource()))
            .toList();
        List<AdminFitmentEntry> fitmentEntries = fitments.findAllByPartId(part.getId()).stream()
            .map(this::toFitmentEntry)
            .toList();
        return new AdminPartResponse(
            part.getId(),
            part.getCategory().getId(),
            part.getCategory().getSlug(),
            part.getNameAz(),
            part.getNameRu(),
            part.getNameEn(),
            part.getBrand(),
            part.getDescription(),
            part.getDefaultImageUrl(),
            numberEntries,
            fitmentEntries
        );
    }

    private AdminFitmentEntry toFitmentEntry(Fitment f) {
        var variant = f.getVehicleVariant();
        return new AdminFitmentEntry(
            f.getId(),
            variant.getId(),
            variant.getModel().getMake().getName(),
            variant.getModel().getName(),
            variant.getYear(),
            variant.getTrim(),
            variant.getEngineCode(),
            f.getPosition()
        );
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s;
    }
}
