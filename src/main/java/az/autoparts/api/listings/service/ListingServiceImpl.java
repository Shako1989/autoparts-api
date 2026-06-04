package az.autoparts.api.listings.service;

import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.catalog.api.dto.PartSummary;
import az.autoparts.api.catalog.service.CatalogService;
import az.autoparts.api.common.error.BadRequestException;
import az.autoparts.api.common.error.ForbiddenException;
import az.autoparts.api.common.error.ResourceNotFoundException;
import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.common.storage.S3StorageService;
import az.autoparts.api.identity.api.dto.SellerSummary;
import az.autoparts.api.identity.service.IdentityService;
import az.autoparts.api.listings.api.dto.AddPhotoRequest;
import az.autoparts.api.listings.api.dto.CreateListingRequest;
import az.autoparts.api.listings.api.dto.ListingDetail;
import az.autoparts.api.listings.api.dto.ListingPhotoResponse;
import az.autoparts.api.listings.api.dto.ListingSummary;
import az.autoparts.api.listings.api.dto.PartListingStats;
import az.autoparts.api.listings.api.dto.PresignedUploadRequest;
import az.autoparts.api.listings.api.dto.PresignedUploadResponse;
import az.autoparts.api.listings.api.dto.UpdateListingRequest;
import az.autoparts.api.listings.domain.Listing;
import az.autoparts.api.listings.domain.ListingPhoto;
import az.autoparts.api.listings.domain.ListingStatus;
import az.autoparts.api.listings.repo.ListingPhotoRepository;
import az.autoparts.api.listings.repo.ListingRepository;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ListingServiceImpl implements ListingService {

    private static final Duration PRESIGN_TTL = Duration.ofMinutes(10);

    private final ListingRepository listings;
    private final ListingPhotoRepository photos;
    private final IdentityService identity;
    private final CatalogService catalog;
    private final S3StorageService storage;

    @Override
    @Transactional
    public ListingDetail createListing(UUID sellerUserId, CreateListingRequest request, Locale locale) {
        UUID sellerId = identity.getSellerProfileIdForUser(sellerUserId)
            .orElseThrow(() -> new ForbiddenException("Become a seller before creating listings"));
        if (!catalog.partExists(request.partId())) {
            throw new ResourceNotFoundException("Part not found: " + request.partId());
        }
        if (request.fitments() != null && !request.fitments().isEmpty()) {
            catalog.addFitments(request.partId(), request.fitments());
        }
        Listing listing = listings.save(Listing.builder()
            .sellerId(sellerId)
            .partId(request.partId())
            .title(request.title())
            .description(request.description())
            .condition(request.condition())
            .priceMinor(request.priceMinor())
            .currency(request.currency())
            .quantity(request.quantity() == 0 ? 1 : request.quantity())
            .status(ListingStatus.ACTIVE)
            .city(request.city())
            .publishedAt(Instant.now())
            .build());
        return hydrate(listing, locale);
    }

    @Override
    @Transactional(readOnly = true)
    public ListingDetail getListing(UUID listingId, Locale locale) {
        Listing listing = listings.findById(listingId)
            .orElseThrow(() -> new ResourceNotFoundException("Listing not found: " + listingId));
        return hydrate(listing, locale);
    }

    @Override
    @Transactional
    public ListingDetail updateListing(UUID sellerUserId, UUID listingId, UpdateListingRequest request, Locale locale) {
        Listing listing = ownedListing(sellerUserId, listingId);
        if (request.title() != null && !request.title().isBlank()) listing.setTitle(request.title());
        if (request.description() != null) listing.setDescription(request.description());
        if (request.condition() != null) listing.setCondition(request.condition());
        if (request.priceMinor() != null) {
            if (request.priceMinor() <= 0) throw new BadRequestException("priceMinor must be > 0");
            listing.setPriceMinor(request.priceMinor());
        }
        if (request.currency() != null && !request.currency().isBlank()) listing.setCurrency(request.currency());
        if (request.quantity() != null) {
            if (request.quantity() < 0) throw new BadRequestException("quantity must be >= 0");
            listing.setQuantity(request.quantity());
        }
        if (request.city() != null) listing.setCity(request.city());
        if (request.status() != null) {
            listing.setStatus(request.status());
            if (request.status() == ListingStatus.ARCHIVED) listing.setArchivedAt(Instant.now());
        }
        listings.save(listing);
        return hydrate(listing, locale);
    }

    @Override
    @Transactional
    public void archiveListing(UUID sellerUserId, UUID listingId) {
        Listing listing = ownedListing(sellerUserId, listingId);
        listing.setStatus(ListingStatus.ARCHIVED);
        listing.setArchivedAt(Instant.now());
        listings.save(listing);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ListingSummary> listForPart(UUID partId, int page, int size) {
        int safePage = Math.max(0, page);
        int safeSize = Math.min(100, Math.max(1, size));
        Page<Listing> result = listings.findActiveByPartId(partId, PageRequest.of(safePage, safeSize));
        return mapToSummaryPage(result);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ListingSummary> listMyListings(UUID sellerUserId, ListingStatus status, int page, int size) {
        UUID sellerId = identity.getSellerProfileIdForUser(sellerUserId)
            .orElseThrow(() -> new ForbiddenException("Not a seller"));
        int safePage = Math.max(0, page);
        int safeSize = Math.min(100, Math.max(1, size));
        Sort sort = Sort.by("createdAt").descending();
        Page<Listing> result = (status == null)
            ? listings.findAllBySellerId(sellerId, PageRequest.of(safePage, safeSize, sort))
            : listings.findAllBySellerIdAndStatus(sellerId, status, PageRequest.of(safePage, safeSize, sort));
        return mapToSummaryPage(result);
    }

    @Override
    @Transactional
    public PresignedUploadResponse requestPhotoUpload(UUID sellerUserId, UUID listingId, PresignedUploadRequest request) {
        Listing listing = ownedListing(sellerUserId, listingId);
        String ext = switch (request.contentType()) {
            case "image/jpeg" -> "jpg";
            case "image/png" -> "png";
            case "image/webp" -> "webp";
            default -> "bin";
        };
        String key = "listings/" + listing.getId() + "/" + UUID.randomUUID() + "." + ext;
        var presigned = storage.presignPut(storage.listingsBucket(), key, request.contentType(), PRESIGN_TTL);
        String publicUrl = storage.publicUrlForListing(key);
        return new PresignedUploadResponse(presigned.uploadUrl(), key, publicUrl, presigned.expiresInSeconds());
    }

    @Override
    @Transactional
    public ListingPhotoResponse addPhoto(UUID sellerUserId, UUID listingId, AddPhotoRequest request) {
        Listing listing = ownedListing(sellerUserId, listingId);
        int nextPosition = request.position() != null
            ? request.position()
            : photos.findAllByListingIdOrderByPositionAsc(listing.getId()).size();
        ListingPhoto saved = photos.save(ListingPhoto.builder()
            .listing(listing)
            .url(storage.publicUrlForListing(request.s3Key()))
            .s3Key(request.s3Key())
            .position(nextPosition)
            .build());
        return new ListingPhotoResponse(saved.getId(), saved.getUrl(), saved.getPosition());
    }

    @Override
    @Transactional
    public void removePhoto(UUID sellerUserId, UUID listingId, UUID photoId) {
        Listing listing = ownedListing(sellerUserId, listingId);
        ListingPhoto photo = photos.findById(photoId)
            .filter(p -> p.getListing().getId().equals(listing.getId()))
            .orElseThrow(() -> new ResourceNotFoundException("Photo not found: " + photoId));
        photos.delete(photo);
        try {
            storage.deleteObject(storage.listingsBucket(), photo.getS3Key());
        } catch (Exception ignored) {
            // best-effort: orphan object is acceptable
        }
    }

    @Override
    @Transactional(readOnly = true)
    public Map<UUID, PartListingStats> countActiveForParts(Collection<UUID> partIds) {
        if (partIds == null || partIds.isEmpty()) return Map.of();
        Map<UUID, PartListingStats> out = new HashMap<>();
        for (var row : listings.findPartListingStats(partIds)) {
            out.put(row.getPartId(), new PartListingStats(
                row.getPartId(),
                row.getActiveCount(),
                row.getMinPriceMinor(),
                row.getCurrency()
            ));
        }
        return out;
    }

    @Override
    @Transactional(readOnly = true)
    public PartListingStats summaryForPart(UUID partId) {
        return countActiveForParts(List.of(partId)).getOrDefault(partId, PartListingStats.empty(partId));
    }

    @Override
    @Transactional(readOnly = true)
    public boolean hasActiveListingsForPart(UUID partId) {
        return summaryForPart(partId).activeCount() > 0;
    }

    // ---------- helpers ----------

    private Listing ownedListing(UUID sellerUserId, UUID listingId) {
        UUID sellerId = identity.getSellerProfileIdForUser(sellerUserId)
            .orElseThrow(() -> new ForbiddenException("Not a seller"));
        return listings.findByIdAndSellerId(listingId, sellerId)
            .orElseThrow(() -> new ForbiddenException("Listing not found or not owned"));
    }

    private ListingDetail hydrate(Listing listing, Locale locale) {
        PartSummary part = catalog.getPartsSummary(List.of(listing.getPartId()), locale)
            .get(listing.getPartId());
        SellerSummary seller = identity.getSellerSummaries(List.of(listing.getSellerId()))
            .get(listing.getSellerId());
        List<ListingPhotoResponse> photoList = photos
            .findAllByListingIdOrderByPositionAsc(listing.getId()).stream()
            .map(p -> new ListingPhotoResponse(p.getId(), p.getUrl(), p.getPosition()))
            .toList();
        return new ListingDetail(
            listing.getId(),
            listing.getTitle(),
            listing.getDescription(),
            listing.getCondition(),
            listing.getStatus(),
            listing.getPriceMinor(),
            listing.getCurrency(),
            listing.getQuantity(),
            listing.getCity(),
            listing.getPublishedAt(),
            listing.getCreatedAt(),
            part,
            seller,
            photoList
        );
    }

    private PageResponse<ListingSummary> mapToSummaryPage(Page<Listing> page) {
        List<Listing> items = page.getContent();
        if (items.isEmpty()) return PageResponse.of(page).map(l -> null);
        var sellerIds = items.stream().map(Listing::getSellerId).distinct().toList();
        Map<UUID, SellerSummary> sellers = identity.getSellerSummaries(sellerIds);
        var listingIds = items.stream().map(Listing::getId).toList();
        Map<UUID, String> thumbByListing = new HashMap<>();
        for (UUID id : listingIds) {
            var ps = photos.findAllByListingIdOrderByPositionAsc(id);
            if (!ps.isEmpty()) thumbByListing.put(id, ps.get(0).getUrl());
        }
        return PageResponse.of(page).map(l -> {
            SellerSummary s = sellers.get(l.getSellerId());
            return new ListingSummary(
                l.getId(),
                l.getPartId(),
                l.getSellerId(),
                s != null ? s.displayName() : null,
                s != null ? s.city() : null,
                l.getTitle(),
                l.getCondition(),
                l.getStatus(),
                l.getPriceMinor(),
                l.getCurrency(),
                l.getQuantity(),
                l.getCity(),
                thumbByListing.get(l.getId()),
                l.getCreatedAt()
            );
        });
    }
}
