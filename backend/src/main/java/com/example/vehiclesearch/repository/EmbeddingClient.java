package com.example.vehiclesearch.repository;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * Client for the Supabase {@code embed} Edge Function (gte-small, 384-dim).
 * Isolated behind this component so the service can request a query embedding
 * and gracefully degrade to fuzzy results if embedding fails.
 */
@Component
public class EmbeddingClient {

    private final RestClient restClient;
    private final String supabaseUrl;
    private final String publishableKey;

    public EmbeddingClient(
            RestClient.Builder builder,
            @Value("${supabase.url:${SUPABASE_URL:}}") String supabaseUrl,
            @Value("${supabase.publishable-key:${SUPABASE_PUBLISHABLE_KEY:}}") String publishableKey) {
        this.restClient = builder.build();
        this.supabaseUrl = supabaseUrl;
        this.publishableKey = publishableKey;
    }

    /** Whether the client is configured to make embedding calls. */
    public boolean isConfigured() {
        return supabaseUrl != null && !supabaseUrl.isBlank()
                && publishableKey != null && !publishableKey.isBlank();
    }

    /**
     * Embed a single query string into a 384-dim vector.
     *
     * @throws EmbeddingException on any transport, auth, or shape failure so the
     *         caller can degrade to fuzzy-only results.
     */
    @SuppressWarnings("unchecked")
    public float[] embed(String text) {
        if (!isConfigured()) {
            throw new EmbeddingException("embedding service is not configured");
        }
        try {
            Map<String, Object> body = restClient.post()
                    .uri(supabaseUrl + "/functions/v1/embed")
                    .header("Authorization", "Bearer " + publishableKey)
                    .header("apikey", publishableKey)
                    .header("Content-Type", "application/json")
                    .body(Map.of("input", text))
                    .retrieve()
                    .body(Map.class);

            if (body == null || !(body.get("embedding") instanceof List<?> raw) || raw.isEmpty()) {
                throw new EmbeddingException("embedding response missing 'embedding' array");
            }
            float[] vector = new float[raw.size()];
            for (int i = 0; i < raw.size(); i++) {
                vector[i] = ((Number) raw.get(i)).floatValue();
            }
            if (vector.length != 384) {
                throw new EmbeddingException("expected 384 dimensions, got " + vector.length);
            }
            return vector;
        } catch (EmbeddingException e) {
            throw e;
        } catch (Exception e) {
            throw new EmbeddingException("embedding call failed: " + e.getMessage(), e);
        }
    }

    /** Raised when a query embedding cannot be produced; triggers fuzzy fallback. */
    public static class EmbeddingException extends RuntimeException {
        public EmbeddingException(String message) {
            super(message);
        }

        public EmbeddingException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
