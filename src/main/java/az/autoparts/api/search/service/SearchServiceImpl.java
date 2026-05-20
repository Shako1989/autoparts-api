package az.autoparts.api.search.service;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.catalog.api.dto.PartSummary;
import az.autoparts.api.catalog.service.CatalogService;
import az.autoparts.api.common.locale.Locale;
import az.autoparts.api.common.pagination.PageResponse;
import az.autoparts.api.listings.api.dto.PartListingStats;
import az.autoparts.api.listings.service.ListingService;
import az.autoparts.api.search.api.dto.SearchHit;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SearchServiceImpl implements SearchService {

    private static final int CANDIDATE_CAP = 500;

    private final EntityManager em;
    private final CatalogService catalog;
    private final ListingService listings;

    @Override
    public PageResponse<SearchHit> search(String q, int page, int size, Locale locale) {
        int safePage = Math.max(0, page);
        int safeSize = Math.min(50, Math.max(1, size));
        String trimmed = q == null ? "" : q.trim();
        if (trimmed.isEmpty()) {
            return new PageResponse<>(List.of(), safePage, safeSize, 0);
        }

        LinkedHashSet<UUID> ordered = new LinkedHashSet<>();
        for (UUID id : exactPartNumberMatches(trimmed)) ordered.add(id);
        for (UUID id : trigramMatches(trimmed, locale, CANDIDATE_CAP)) ordered.add(id);

        List<UUID> all = new ArrayList<>(ordered);
        long total = all.size();
        int from = Math.min(safePage * safeSize, all.size());
        int to = Math.min(from + safeSize, all.size());
        List<UUID> pageIds = all.subList(from, to);

        Map<UUID, PartSummary> summaries = catalog.getPartsSummary(pageIds, locale);
        Map<UUID, PartListingStats> stats = listings.countActiveForParts(pageIds);

        List<SearchHit> hits = new ArrayList<>(pageIds.size());
        for (UUID id : pageIds) {
            PartSummary s = summaries.get(id);
            if (s == null) continue;
            PartListingStats st = stats.getOrDefault(id, PartListingStats.empty(id));
            hits.add(new SearchHit(
                s.id(), s.name(), s.brand(), s.categorySlug(), s.defaultImageUrl(),
                st.activeCount(), st.minPriceMinor(), st.currency()
            ));
        }
        return new PageResponse<>(hits, safePage, safeSize, total);
    }

    @SuppressWarnings("unchecked")
    private List<UUID> exactPartNumberMatches(String q) {
        String qNoWs = q.replaceAll("\\s+", "").toUpperCase();
        if (qNoWs.length() < 3) return List.of();
        var query = em.createNativeQuery("""
            select distinct cast(pn.part_id as varchar)
              from part_numbers pn
              join parts p on p.id = pn.part_id
             where p.deleted_at is null
               and upper(replace(pn.number, ' ', '')) = :q
            """);
        query.setParameter("q", qNoWs);
        List<Object> rows = query.getResultList();
        List<UUID> out = new ArrayList<>(rows.size());
        for (Object r : rows) out.add(UUID.fromString(r.toString()));
        return out;
    }

    @SuppressWarnings("unchecked")
    private List<UUID> trigramMatches(String q, Locale locale, int cap) {
        String column = switch (locale) {
            case RU -> "name_ru";
            case EN -> "name_en";
            case AZ -> "name_az";
        };
        var query = em.createNativeQuery("""
            select cast(p.id as varchar)
              from parts p
             where p.deleted_at is null
               and %s %% :q
             order by similarity(%s, :q) desc
             limit :cap
            """.formatted(column, column));
        query.setParameter("q", q);
        query.setParameter("cap", cap);
        List<Object> rows = query.getResultList();
        List<UUID> out = new ArrayList<>(rows.size());
        for (Object r : rows) out.add(UUID.fromString(r.toString()));
        return out;
    }
}
