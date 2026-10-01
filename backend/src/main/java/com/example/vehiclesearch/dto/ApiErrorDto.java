package com.example.vehiclesearch.dto;

/** Consistent error body for 4xx/5xx responses. */
public record ApiErrorDto(
        int status,
        String error,
        String message) {
}
