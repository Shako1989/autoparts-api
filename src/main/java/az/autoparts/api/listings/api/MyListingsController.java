package az.autoparts.api.listings.api;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.common.security.CurrentUser;
import az.autoparts.api.listings.api.dto.ListingSummary;
import az.autoparts.api.listings.domain.ListingStatus;
import az.autoparts.api.listings.service.ListingService;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/my/listings")
@RequiredArgsConstructor
public class MyListingsController {

    private final ListingService listingService;

    @GetMapping
    @PreAuthorize("hasRole('SELLER')")
    public PageResponse<ListingSummary> list(
        @RequestParam(required = false) ListingStatus status,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        return listingService.listMyListings(CurrentUser.requireId(), status, page, size);
    }
}
