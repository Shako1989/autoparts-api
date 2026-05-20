package az.autoparts.api.listings.api;

import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.listings.api.dto.ListingSummary;
import az.autoparts.api.listings.api.dto.PartListingStats;
import az.autoparts.api.listings.service.ListingService;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/parts/{partId}/listings")
@RequiredArgsConstructor
public class PartListingsController {

    private final ListingService listingService;

    @GetMapping
    public PageResponse<ListingSummary> list(
        @PathVariable UUID partId,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        return listingService.listForPart(partId, page, size);
    }

    @GetMapping("/summary")
    public PartListingStats summary(@PathVariable UUID partId) {
        return listingService.summaryForPart(partId);
    }
}
