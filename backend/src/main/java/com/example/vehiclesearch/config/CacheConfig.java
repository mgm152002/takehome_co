package com.example.vehiclesearch.config;

import com.github.benmanes.caffeine.cache.Caffeine;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCache;
import org.springframework.cache.support.SimpleCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;
import java.util.List;

/**
 * Caffeine cache setup. Two independent caches with different TTLs and bounded
 * sizes, per the design:
 * <ul>
 *   <li>{@code suggestions} — 30 min TTL, autocomplete responses.</li>
 *   <li>{@code searchPages} — 5 min TTL, search result pages.</li>
 * </ul>
 * Cache keys include {@code datasetVersion}; a successful import bumps the
 * version and {@link com.example.vehiclesearch.service.DatasetVersionService}
 * clears both caches, so stale entries are never served.
 */
@Configuration
@EnableCaching
public class CacheConfig {

    public static final String SUGGESTIONS_CACHE = "suggestions";
    public static final String SEARCH_PAGES_CACHE = "searchPages";

    @Bean
    public CacheManager cacheManager() {
        CaffeineCache suggestions = new CaffeineCache(
                SUGGESTIONS_CACHE,
                Caffeine.newBuilder()
                        .expireAfterWrite(Duration.ofMinutes(30))
                        .maximumSize(10_000)
                        .build());

        CaffeineCache searchPages = new CaffeineCache(
                SEARCH_PAGES_CACHE,
                Caffeine.newBuilder()
                        .expireAfterWrite(Duration.ofMinutes(5))
                        .maximumSize(5_000)
                        .build());

        SimpleCacheManager manager = new SimpleCacheManager();
        manager.setCaches(List.of(suggestions, searchPages));
        return manager;
    }
}
