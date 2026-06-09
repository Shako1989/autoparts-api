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

import az.autoparts.api.catalog.api.admin.dto.AdminCalloutEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminCategoryResponse;
import az.autoparts.api.catalog.api.admin.dto.AdminDiagramListItem;
import az.autoparts.api.catalog.api.admin.dto.AdminDiagramResponse;
import az.autoparts.api.catalog.api.admin.dto.AdminFitmentEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminPartListItem;
import az.autoparts.api.catalog.api.admin.dto.AdminPartNumberEntry;
import az.autoparts.api.catalog.api.admin.dto.AdminPartCalloutLocation;
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
import az.autoparts.api.catalog.domain.Category;
import az.autoparts.api.catalog.domain.Diagram;
import az.autoparts.api.catalog.domain.DiagramCallout;
import az.autoparts.api.catalog.domain.Fitment;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.catalog.domain.PartNumber;
import az.autoparts.api.catalog.domain.VehicleVariant;
import az.autoparts.api.catalog.repo.CategoryRepository;
import az.autoparts.api.catalog.repo.DiagramCalloutRepository;
import az.autoparts.api.catalog.repo.DiagramRepository;
import az.autoparts.api.catalog.repo.FitmentRepository;
import az.autoparts.api.catalog.repo.PartNumberRepository;
import az.autoparts.api.catalog.repo.PartRepository;
import az.autoparts.api.catalog.repo.VehicleVariantRepository;
import az.autoparts.api.common.error.BadRequestException;
import az.autoparts.api.common.error.ResourceNotFoundException;
import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.common.storage.S3StorageService;
import az.autoparts.api.listings.service.ListingService;
import java.time.Duration;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class CatalogAdminServiceImpl implements CatalogAdminService {

    private static final Duration PRESIGN_TTL = Duration.ofMinutes(10);

    private final CategoryRepository categories;
    private final PartRepository parts;
    private final PartNumberRepository partNumbers;
    private final FitmentRepository fitments;
    private final DiagramRepository diagrams;
    private final DiagramCalloutRepository diagramCallouts;
    private final VehicleVariantRepository variants;
    private final CatalogService catalogService;
    private final ListingService listingService;
    private final S3StorageService storage;

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

    // ---------- diagrams ----------

    @Override
    @Transactional(readOnly = true)
    public List<AdminDiagramListItem> listDiagrams(UUID categoryId) {
        List<Diagram> source = categoryId != null
            ? diagrams.findAllByCategoryId(categoryId)
            : diagrams.findAll();
        List<UUID> diagramIds = source.stream().map(Diagram::getId).toList();
        Map<UUID, Long> calloutCounts = new HashMap<>();
        for (UUID id : diagramIds) {
            calloutCounts.put(id, (long) diagramCallouts.findAllByDiagramId(id).size());
        }
        return source.stream()
            .map(d -> new AdminDiagramListItem(
                d.getId(),
                d.getSlug(),
                d.getTitleEn(),
                d.getCategory() == null ? null : d.getCategory().getId(),
                d.getCategory() == null ? null : d.getCategory().getSlug(),
                d.getImageUrl(),
                calloutCounts.getOrDefault(d.getId(), 0L)
            ))
            .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public AdminDiagramResponse getDiagram(UUID diagramId) {
        Diagram d = diagrams.findById(diagramId)
            .orElseThrow(() -> new ResourceNotFoundException("Diagram not found: " + diagramId));
        return toDiagramResponse(d);
    }

    @Override
    @Transactional
    public AdminDiagramResponse createDiagram(CreateDiagramRequest request) {
        if (diagrams.findBySlug(request.slug()).isPresent()) {
            throw new BadRequestException("Diagram slug already exists: " + request.slug());
        }
        if (request.categoryId() == null && request.vehicleVariantId() == null) {
            throw new BadRequestException("At least one of categoryId or vehicleVariantId is required");
        }
        Category category = null;
        if (request.categoryId() != null) {
            category = categories.findById(request.categoryId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + request.categoryId()));
        }
        VehicleVariant variant = null;
        if (request.vehicleVariantId() != null) {
            variant = variants.findById(request.vehicleVariantId())
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle variant not found: " + request.vehicleVariantId()));
        }
        Diagram saved = diagrams.save(Diagram.builder()
            .slug(request.slug())
            .titleAz(request.titleAz())
            .titleRu(request.titleRu())
            .titleEn(request.titleEn())
            .imageUrl(request.imageUrl())
            .imageWidth(request.imageWidth())
            .imageHeight(request.imageHeight())
            .category(category)
            .vehicleVariant(variant)
            .build());
        return toDiagramResponse(saved);
    }

    @Override
    @Transactional
    public AdminDiagramResponse updateDiagram(UUID diagramId, UpdateDiagramRequest request) {
        Diagram d = diagrams.findById(diagramId)
            .orElseThrow(() -> new ResourceNotFoundException("Diagram not found: " + diagramId));
        if (request.titleAz() != null && !request.titleAz().isBlank()) d.setTitleAz(request.titleAz());
        if (request.titleRu() != null && !request.titleRu().isBlank()) d.setTitleRu(request.titleRu());
        if (request.titleEn() != null && !request.titleEn().isBlank()) d.setTitleEn(request.titleEn());
        if (request.imageUrl() != null && !request.imageUrl().isBlank()) d.setImageUrl(request.imageUrl());
        if (request.imageWidth() != null) d.setImageWidth(request.imageWidth());
        if (request.imageHeight() != null) d.setImageHeight(request.imageHeight());
        if (request.categoryId() != null) {
            Category category = categories.findById(request.categoryId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found: " + request.categoryId()));
            d.setCategory(category);
        }
        if (request.vehicleVariantId() != null) {
            VehicleVariant variant = variants.findById(request.vehicleVariantId())
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle variant not found: " + request.vehicleVariantId()));
            d.setVehicleVariant(variant);
        }
        return toDiagramResponse(diagrams.save(d));
    }

    @Override
    @Transactional
    public void deleteDiagram(UUID diagramId) {
        Diagram d = diagrams.findById(diagramId)
            .orElseThrow(() -> new ResourceNotFoundException("Diagram not found: " + diagramId));
        diagrams.delete(d);
    }

    @Override
    @Transactional
    public AdminCalloutEntry addCallout(UUID diagramId, CreateCalloutRequest request) {
        Diagram d = diagrams.findById(diagramId)
            .orElseThrow(() -> new ResourceNotFoundException("Diagram not found: " + diagramId));
        Part part = parts.findById(request.partId())
            .orElseThrow(() -> new ResourceNotFoundException("Part not found: " + request.partId()));
        if (request.x() < 0 || request.x() > d.getImageWidth()
            || request.y() < 0 || request.y() > d.getImageHeight()) {
            throw new BadRequestException("Callout position is outside the image bounds");
        }
        boolean labelTaken = diagramCallouts.findAllByDiagramId(diagramId).stream()
            .anyMatch(c -> c.getLabel().equals(request.label()));
        if (labelTaken) {
            throw new BadRequestException("A callout with label '" + request.label() + "' already exists");
        }
        DiagramCallout saved = diagramCallouts.save(DiagramCallout.builder()
            .diagram(d)
            .part(part)
            .label(request.label())
            .x(request.x())
            .y(request.y())
            .w(request.w())
            .h(request.h())
            .zOrder(request.zOrder() == null ? 0 : request.zOrder())
            .notes(blankToNull(request.notes()))
            .build());
        return toCalloutEntry(saved);
    }

    @Override
    @Transactional
    public AdminCalloutEntry updateCallout(UUID diagramId, UUID calloutId, UpdateCalloutRequest request) {
        DiagramCallout callout = loadOwnedCallout(diagramId, calloutId);
        if (request.partId() != null && !request.partId().equals(callout.getPart().getId())) {
            Part part = parts.findById(request.partId())
                .orElseThrow(() -> new ResourceNotFoundException("Part not found: " + request.partId()));
            callout.setPart(part);
        }
        if (request.label() != null && !request.label().isBlank()
            && !request.label().equals(callout.getLabel())) {
            boolean taken = diagramCallouts.findAllByDiagramId(diagramId).stream()
                .anyMatch(c -> !c.getId().equals(calloutId) && c.getLabel().equals(request.label()));
            if (taken) {
                throw new BadRequestException("A callout with label '" + request.label() + "' already exists");
            }
            callout.setLabel(request.label());
        }
        Diagram d = callout.getDiagram();
        if (request.x() != null) {
            if (request.x() < 0 || request.x() > d.getImageWidth()) {
                throw new BadRequestException("x is outside the image bounds");
            }
            callout.setX(request.x());
        }
        if (request.y() != null) {
            if (request.y() < 0 || request.y() > d.getImageHeight()) {
                throw new BadRequestException("y is outside the image bounds");
            }
            callout.setY(request.y());
        }
        if (request.w() != null) callout.setW(request.w() == 0 ? null : request.w());
        if (request.h() != null) callout.setH(request.h() == 0 ? null : request.h());
        if (request.zOrder() != null) callout.setZOrder(request.zOrder());
        if (request.notes() != null) callout.setNotes(blankToNull(request.notes()));
        return toCalloutEntry(diagramCallouts.save(callout));
    }

    @Override
    @Transactional
    public void removeCallout(UUID diagramId, UUID calloutId) {
        DiagramCallout callout = loadOwnedCallout(diagramId, calloutId);
        diagramCallouts.delete(callout);
    }

    private DiagramCallout loadOwnedCallout(UUID diagramId, UUID calloutId) {
        DiagramCallout c = diagramCallouts.findById(calloutId)
            .orElseThrow(() -> new ResourceNotFoundException("Callout not found: " + calloutId));
        if (!c.getDiagram().getId().equals(diagramId)) {
            throw new ResourceNotFoundException("Callout does not belong to diagram: " + diagramId);
        }
        return c;
    }

    private AdminDiagramResponse toDiagramResponse(Diagram d) {
        List<AdminCalloutEntry> callouts = diagramCallouts.findAllByDiagramId(d.getId()).stream()
            .map(this::toCalloutEntry)
            .toList();
        return new AdminDiagramResponse(
            d.getId(),
            d.getSlug(),
            d.getTitleAz(),
            d.getTitleRu(),
            d.getTitleEn(),
            d.getImageUrl(),
            d.getImageWidth(),
            d.getImageHeight(),
            d.getCategory() == null ? null : d.getCategory().getId(),
            d.getCategory() == null ? null : d.getCategory().getSlug(),
            d.getVehicleVariant() == null ? null : d.getVehicleVariant().getId(),
            callouts
        );
    }

    private AdminCalloutEntry toCalloutEntry(DiagramCallout c) {
        return new AdminCalloutEntry(
            c.getId(),
            c.getLabel(),
            c.getX(),
            c.getY(),
            c.getW(),
            c.getH(),
            c.getZOrder(),
            c.getNotes(),
            c.getPart().getId(),
            c.getPart().getNameEn()
        );
    }

    // ---------- uploads ----------

    @Override
    public AdminPresignedUploadResponse presignCatalogImageUpload(String contentType) {
        String ext = switch (contentType) {
            case "image/jpeg" -> "jpg";
            case "image/png" -> "png";
            case "image/webp" -> "webp";
            case "image/svg+xml" -> "svg";
            default -> throw new BadRequestException("Unsupported content type: " + contentType);
        };
        String key = "catalog/" + UUID.randomUUID() + "." + ext;
        var presigned = storage.presignPut(storage.catalogBucket(), key, contentType, PRESIGN_TTL);
        return new AdminPresignedUploadResponse(
            presigned.uploadUrl(),
            key,
            storage.publicUrlForCatalog(key),
            presigned.expiresInSeconds()
        );
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
        List<AdminPartCalloutLocation> calloutLocations = diagramCallouts.findAllByPartId(part.getId()).stream()
            .map(c -> new AdminPartCalloutLocation(
                c.getId(),
                c.getDiagram().getId(),
                c.getDiagram().getSlug(),
                c.getDiagram().getTitleEn(),
                c.getDiagram().getImageUrl(),
                c.getDiagram().getImageWidth(),
                c.getDiagram().getImageHeight(),
                c.getLabel(),
                c.getX(),
                c.getY()
            ))
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
            fitmentEntries,
            calloutLocations
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
