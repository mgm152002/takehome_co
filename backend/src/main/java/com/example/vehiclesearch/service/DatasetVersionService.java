package com.example.vehiclesearch.service;

import com.example.vehiclesearch.repository.SearchRepository;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Service;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Tracks the dataset version and clears both Caffeine caches when a new import
 * bumps it. The observed version is also folded into every cache key so stale
 * entries can never be reused after an import.
 */
@Service
public class DatasetVersionService {

    private final SearchRepository repository;
    private final CacheManager cacheManager;
    private final AtomicLong lastSeenVersion = new AtomicLong(Long.MIN_VALUE);

    public DatasetVersionService(SearchRepository repository, CacheManager cacheManager) {
        this.repository = repository;
        this.cacheManager = cacheManager;
    }

    /**
     * Read the current version. If it changed since the last read, evict both
     * caches so nothing computed against the old dataset survives.
     */
    public long currentVersion() {
        long version = repository.datasetVersion();
        long previous = lastSeenVersion.getAndSet(version);
        if (previous != Long.MIN_VALUE && previous != version) {
            clearCaches();
        }
        return version;
    }

    private void clearCaches() {
        for (String name : cacheManager.getCacheNames()) {
            var cache = cacheManager.getCache(name);
            if (cache != null) {
                cache.clear();
            }
        }
    }

    /**
     * The version observed by the most recent {@link #currentVersion()} call,
     * without a DB round-trip or cache side effect. Safe to read inside a
     * method body after the {@code @Cacheable} key SpEL has already called
     * {@link #currentVersion()}.
     */
    public long lastKnownVersion() {
        long v = lastSeenVersion.get();
        return v == Long.MIN_VALUE ? 0L : v;
    }
}
