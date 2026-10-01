package com.example.vehiclesearch.controller;

import com.example.vehiclesearch.dto.SearchResponseDto;
import com.example.vehiclesearch.dto.SuggestionResponseDto;
import com.example.vehiclesearch.service.SearchService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Presentation layer. Maps HTTP requests to the service, performs basic request
 * validation, and returns response DTOs (200 by default; validation failures
 * and errors are translated to status codes by {@link ApiExceptionHandler}).
 * No business logic lives here.
 */
@RestController
@RequestMapping("/api")
@Validated
public class SearchController {

    private final SearchService searchService;

    public SearchController(SearchService searchService) {
        this.searchService = searchService;
    }

    @GetMapping("/suggestions")
    public SuggestionResponseDto suggestions(
            @RequestParam("q") @NotBlank String q) {
        return searchService.suggest(q.trim());
    }

    @GetMapping("/search")
    public SearchResponseDto search(
            @RequestParam("q") @NotBlank String q,
            @RequestParam(value = "page", defaultValue = "0") @Min(0) int page,
            @RequestParam(value = "size", defaultValue = "100") @Min(1) @Max(100) int size) {
        return searchService.search(q.trim(), page, size);
    }
}
