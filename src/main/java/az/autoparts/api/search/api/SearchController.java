package az.autoparts.api.search.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.search.api.dto.SearchHit;
import az.autoparts.api.search.service.SearchService;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/search")
@RequiredArgsConstructor
public class SearchController {

    private final SearchService searchService;

    @GetMapping
    public PageResponse<SearchHit> search(
        @RequestParam(value = "q", defaultValue = "") String q,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestHeader(name = "Accept-Language", required = false) String acceptLanguage
    ) {
        return searchService.search(q, page, size, Locale.fromHeaderOrDefault(acceptLanguage));
    }
}
