package az.autoparts.api.search.service;

import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.search.api.dto.SearchHit;

public interface SearchService {

    PageResponse<SearchHit> search(String q, int page, int size, Locale locale);
}
