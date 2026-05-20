package az.autoparts.api.listings.api;

import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.security.CurrentUser;
import az.autoparts.api.listings.api.dto.AddPhotoRequest;
import az.autoparts.api.listings.api.dto.CreateListingRequest;
import az.autoparts.api.listings.api.dto.ListingDetail;
import az.autoparts.api.listings.api.dto.ListingPhotoResponse;
import az.autoparts.api.listings.api.dto.PresignedUploadRequest;
import az.autoparts.api.listings.api.dto.PresignedUploadResponse;
import az.autoparts.api.listings.api.dto.UpdateListingRequest;
import az.autoparts.api.listings.service.ListingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/listings")
@RequiredArgsConstructor
public class ListingController {

    private final ListingService listingService;

    @GetMapping("/{id}")
    public ListingDetail getListing(
        @PathVariable UUID id,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return listingService.getListing(id, Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @PostMapping
    @PreAuthorize("hasRole('SELLER')")
    public ListingDetail create(
        @Valid @RequestBody CreateListingRequest request,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return listingService.createListing(
            CurrentUser.requireId(), request, Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasRole('SELLER')")
    public ListingDetail update(
        @PathVariable UUID id,
        @Valid @RequestBody UpdateListingRequest request,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return listingService.updateListing(
            CurrentUser.requireId(), id, request, Locale.fromHeaderOrDefault(acceptLanguage));
    }

    @PostMapping("/{id}/photos/presign")
    @PreAuthorize("hasRole('SELLER')")
    public PresignedUploadResponse presignPhoto(
        @PathVariable UUID id,
        @Valid @RequestBody PresignedUploadRequest request
    ) {
        return listingService.requestPhotoUpload(CurrentUser.requireId(), id, request);
    }

    @PostMapping("/{id}/photos")
    @PreAuthorize("hasRole('SELLER')")
    public ListingPhotoResponse addPhoto(
        @PathVariable UUID id,
        @Valid @RequestBody AddPhotoRequest request
    ) {
        return listingService.addPhoto(CurrentUser.requireId(), id, request);
    }

    @DeleteMapping("/{id}/photos/{photoId}")
    @PreAuthorize("hasRole('SELLER')")
    public ResponseEntity<Void> removePhoto(@PathVariable UUID id, @PathVariable UUID photoId) {
        listingService.removePhoto(CurrentUser.requireId(), id, photoId);
        return ResponseEntity.noContent().build();
    }
}
