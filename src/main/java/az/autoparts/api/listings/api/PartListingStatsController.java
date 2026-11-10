package az.autoparts.api.listings.api;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.common.error.BadRequestException;
import az.autoparts.api.listings.api.dto.PartListingStats;
import az.autoparts.api.listings.service.ListingService;
import lombok.RequiredArgsConstructor;

/**
 * Active-offer stats for many parts in one request, so a list page can show
 * "from X ₼" badges without calling {@code /parts/{id}/listings/summary} per card.
 */
@RestController
@RequestMapping("/api/v1/parts/listings-summary")
@RequiredArgsConstructor
public class PartListingStatsController {

    static final int MAX_IDS = 100;

    private final ListingService listingService;

    /** Stats in request order (duplicates dropped); a part without offers has zero and no price. */
    @GetMapping
    public List<PartListingStats> summaries(@RequestParam("ids") List<UUID> ids) {
        List<UUID> distinct = ids.stream().distinct().toList();
        if (distinct.size() > MAX_IDS) {
            throw new BadRequestException("At most " + MAX_IDS + " part ids per request");
        }
        Map<UUID, PartListingStats> found = listingService.countActiveForParts(distinct);
        return distinct.stream()
            .map(id -> found.getOrDefault(id, PartListingStats.empty(id)))
            .toList();
    }
}
