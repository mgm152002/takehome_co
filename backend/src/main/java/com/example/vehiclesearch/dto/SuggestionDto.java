package com.example.vehiclesearch.dto;

/** A single autocomplete suggestion. */
public record SuggestionDto(
        String term,
        String termType,
        float score) {
}
