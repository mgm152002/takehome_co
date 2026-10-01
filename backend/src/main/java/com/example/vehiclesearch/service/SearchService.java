package com.example.vehiclesearch.service;

import com.example.vehiclesearch.dto.MatchType;
import com.example.vehiclesearch.dto.SearchItemDto;
import com.example.vehiclesearch.dto.SearchResponseDto;
import com.example.vehiclesearch.dto.SuggestionDto;
import com.example.vehiclesearch.dto.SuggestionResponseDto;
import com.example.vehiclesearch.model.VehicleListing;
import com.example.vehiclesearch.repository.EmbeddingClient;
import com.example.vehiclesearch.repository.SearchRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Business layer. Holds the search rules and cache policy and is completely
 * isolated from HTTP concerns (no servlet types). Applies the design's
 * conditional fallback: exact/fuzzy first, and semantic only when exact
 * returns nothing and fuzzy is thin, degrading to fuzzy on embedding failure.
 */
@Service
public class SearchService {

    private static final Logger log = LoggerFactory.getLogger(SearchService.class);

    /** Semantic fires only when exact=0 AND fuzzy < this many results. */
    private static final int FUZZY_SUFFICIENCY_THRESHOLD = 100;
    private static final double SEMANTIC_MATCH_THRESHOLD = 0.55;
    static final int MAX_PAGE_SIZE = 100;
    static final int MAX_SUGGESTIONS = 8;

    private final SearchRepository repository;
    private final EmbeddingClient embeddingClient;
    private final DatasetVersionService versionService;

    public SearchService(
            SearchRepository repository,
            EmbeddingClient embeddingClient,
            DatasetVersionService versionService) {
        this.repository = repository;
        this.embeddingClient = embeddingClient;
        this.versionService = versionService;
    }

    /**
     * Autocomplete. Cached 30 min (see CacheConfig) and keyed by normalized
     * query + datasetVersion so an import invalidates stale prefixes.
     */
    @Cacheable(cacheNames = "suggestions", key = "#query.toLowerCase().trim() + '|' + #root.target.currentVersion()")
    public SuggestionResponseDto suggest(String query) {
        long version = versionService.lastKnownVersion();
        List<SuggestionDto> items = repository.suggestions(query, MAX_SUGGESTIONS);
        return new SuggestionResponseDto(query, items, version);
    }

    /**
     * Full search with conditional semantic fallback. Cached 5 min and keyed by
     * normalized query + page + size + datasetVersion.
     */
    @Cacheable(cacheNames = "searchPages",
            key = "#query.toLowerCase().trim() + '|' + #page + '|' + #size + '|' + #root.target.currentVersion()")
    public SearchResponseDto search(String query, int page, int size) {
        long version = versionService.lastKnownVersion();
        int effectiveSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        int effectivePage = Math.max(page, 0);

        List<VehicleListing> exactFuzzy = repository.searchExactFuzzy(query, effectivePage, effectiveSize);

        long exactCount = exactFuzzy.stream().filter(v -> v.getMatchType() == MatchType.EXACT).count();
        boolean fuzzyThin = exactFuzzy.size() < FUZZY_SUFFICIENCY_THRESHOLD;

        if (exactCount == 0 && fuzzyThin) {
            List<VehicleListing> semantic = trySemantic(query, effectivePage, effectiveSize);
            if (semantic != null && !semantic.isEmpty()) {
                return toResponse(query, effectivePage, effectiveSize, semantic, MatchType.SEMANTIC, version);
            }
        }

        MatchType mode = exactCount > 0 ? MatchType.EXACT
                : (exactFuzzy.isEmpty() ? MatchType.EXACT : MatchType.FUZZY);
        return toResponse(query, effectivePage, effectiveSize, exactFuzzy, mode, version);
    }

    /** Returns semantic results, or null if embedding/semantic fails (fuzzy fallback). */
    private List<VehicleListing> trySemantic(String query, int page, int size) {
        try {
            float[] embedding = embeddingClient.embed(query);
            return repository.searchSemantic(embedding, page, size, SEMANTIC_MATCH_THRESHOLD);
        } catch (Exception e) {
            log.warn("semantic fallback failed for query '{}', degrading to fuzzy: {}", query, e.getMessage());
            return null;
        }
    }

    private SearchResponseDto toResponse(
            String query, int page, int size, List<VehicleListing> rows, MatchType mode, long version) {
        boolean hasNext = !rows.isEmpty() && rows.get(0).isHasNext();
        double elapsedMs = rows.isEmpty() ? 0.0 : rows.get(0).getElapsedMs();
        List<SearchItemDto> items = rows.stream().map(SearchService::toItem).toList();
        return new SearchResponseDto(query, page, size, items, hasNext, mode, version, elapsedMs);
    }

    private static SearchItemDto toItem(VehicleListing v) {
        return new SearchItemDto(
                v.getId(), v.getYear(), v.getMake(), v.getModel(), v.getTrim(), v.getBody(),
                v.getTransmission(), v.getVin(), v.getState(), v.getConditionScore(), v.getOdometer(),
                v.getColor(), v.getInterior(), v.getSeller(), v.getMmr(), v.getSellingPrice(),
                v.getSaleDate(), v.getMatchType(), v.getScore());
    }

    /** Exposed for cache-key SpEL. */
    public long currentVersion() {
        return versionService.currentVersion();
    }
}
