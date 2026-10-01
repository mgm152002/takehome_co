package com.example.vehiclesearch.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** One listing in a search result page. Mirrors the columns returned by the
 *  search_vehicle_listings / search_semantic_vehicle_listings SQL functions. */
public record SearchItemDto(
        long id,
        Integer year,
        String make,
        String model,
        String trim,
        String body,
        String transmission,
        String vin,
        String state,
        BigDecimal conditionScore,
        Long odometer,
        String color,
        String interior,
        String seller,
        BigDecimal mmr,
        BigDecimal sellingPrice,
        OffsetDateTime saleDate,
        MatchType matchType,
        float score) {
}
