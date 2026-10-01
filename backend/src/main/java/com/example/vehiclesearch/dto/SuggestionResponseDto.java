package com.example.vehiclesearch.dto;

import java.util.List;

/** Response for GET /api/suggestions. */
public record SuggestionResponseDto(
        String query,
        List<SuggestionDto> suggestions,
        long datasetVersion) {
}
