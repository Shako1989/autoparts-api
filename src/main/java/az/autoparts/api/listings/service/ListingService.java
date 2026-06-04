package az.autoparts.api.listings.service;

import java.util.Collection;
import java.util.Map;
import java.util.UUID;

import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.listings.api.dto.AddPhotoRequest;
import az.autoparts.api.listings.api.dto.CreateListingRequest;
import az.autoparts.api.listings.api.dto.ListingDetail;
import az.autoparts.api.listings.api.dto.ListingPhotoResponse;
import az.autoparts.api.listings.api.dto.ListingSummary;
import az.autoparts.api.listings.api.dto.PartListingStats;
import az.autoparts.api.listings.api.dto.PresignedUploadRequest;
import az.autoparts.api.listings.api.dto.PresignedUploadResponse;
import az.autoparts.api.listings.api.dto.UpdateListingRequest;
import az.autoparts.api.listings.domain.ListingStatus;

public interface ListingService {

    ListingDetail createListing(UUID sellerUserId, CreateListingRequest request, Locale locale);

    ListingDetail getListing(UUID listingId, Locale locale);

    ListingDetail updateListing(UUID sellerUserId, UUID listingId, UpdateListingRequest request, Locale locale);

    void archiveListing(UUID sellerUserId, UUID listingId);

    PageResponse<ListingSummary> listForPart(UUID partId, int page, int size);

    PageResponse<ListingSummary> listMyListings(UUID sellerUserId, ListingStatus status, int page, int size);

    PresignedUploadResponse requestPhotoUpload(UUID sellerUserId, UUID listingId, PresignedUploadRequest request);

    ListingPhotoResponse addPhoto(UUID sellerUserId, UUID listingId, AddPhotoRequest request);

    void removePhoto(UUID sellerUserId, UUID listingId, UUID photoId);

    Map<UUID, PartListingStats> countActiveForParts(Collection<UUID> partIds);

    PartListingStats summaryForPart(UUID partId);

    /**
     * Whether any ACTIVE listing references the given part. Used by admin
     * delete-part to block destructive operations.
     */
    boolean hasActiveListingsForPart(UUID partId);
}
