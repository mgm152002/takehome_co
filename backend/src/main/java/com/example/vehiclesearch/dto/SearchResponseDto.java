package com.example.vehiclesearch.dto;

import java.util.List;

/** Response for GET /api/search. */
public record SearchResponseDto(
        String query,
        int page,
        int size,
        List<SearchItemDto> results,
        boolean hasNext,
        MatchType mode,
        long datasetVersion,
        double elapsedMs) {
}
