package com.example.vehiclesearch.repository;

import com.example.vehiclesearch.dto.MatchType;
import com.example.vehiclesearch.dto.SuggestionDto;
import com.example.vehiclesearch.model.VehicleListing;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Persistence layer. Talks directly to PostgreSQL through {@link JdbcTemplate},
 * calling the search stored functions defined in the Supabase migrations. It
 * returns domain models and knows nothing about HTTP or caching.
 *
 * <p>The dataset is exposed through stored functions (full-text, trigram and
 * pgvector search), not plain tables, so JdbcTemplate is used rather than JPA
 * entity mapping — a function result set cannot be mapped as a managed entity.
 */
@Repository
public class SearchRepository {

    private final JdbcTemplate jdbc;

    public SearchRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<VehicleListing> LISTING_MAPPER = (rs, rowNum) -> {
        VehicleListing v = new VehicleListing();
        v.setId(rs.getLong("id"));
        int year = rs.getInt("year");
        v.setYear(rs.wasNull() ? null : year);
        v.setMake(rs.getString("make"));
        v.setModel(rs.getString("model"));
        v.setTrim(rs.getString("trim"));
        v.setBody(rs.getString("body"));
        v.setTransmission(rs.getString("transmission"));
        v.setVin(rs.getString("vin"));
        v.setState(rs.getString("state"));
        v.setConditionScore(rs.getBigDecimal("condition_score"));
        long odo = rs.getLong("odometer");
        v.setOdometer(rs.wasNull() ? null : odo);
        v.setColor(rs.getString("color"));
        v.setInterior(rs.getString("interior"));
        v.setSeller(rs.getString("seller"));
        v.setMmr(rs.getBigDecimal("mmr"));
        v.setSellingPrice(rs.getBigDecimal("selling_price"));
        var saleDate = rs.getObject("sale_date", java.time.OffsetDateTime.class);
        v.setSaleDate(saleDate);
        v.setMatchType(MatchType.valueOf(rs.getString("match_type")));
        v.setScore(rs.getFloat("score"));
        v.setHasNext(rs.getBoolean("has_next"));
        v.setElapsedMs(rs.getDouble("elapsed_ms"));
        return v;
    };

    private static final RowMapper<SuggestionDto> SUGGESTION_MAPPER = (rs, rowNum) ->
            new SuggestionDto(rs.getString("term"), rs.getString("term_type"), rs.getFloat("score"));

    /** Exact + fuzzy search, ranked and paginated by the SQL function. */
    public List<VehicleListing> searchExactFuzzy(String query, int page, int size) {
        return jdbc.query(
                "select * from public.search_vehicle_listings(?, ?, ?)",
                LISTING_MAPPER, query, page, size);
    }

    /** Semantic search over profile embeddings for a pre-computed query vector. */
    public List<VehicleListing> searchSemantic(float[] queryEmbedding, int page, int size, double threshold) {
        String literal = toVectorLiteral(queryEmbedding);
        return jdbc.query(
                "select * from public.search_semantic_vehicle_listings(?::extensions.vector, ?, ?, ?)",
                LISTING_MAPPER, literal, page, size, (float) threshold);
    }

    /** Prefix + fuzzy autocomplete terms. */
    public List<SuggestionDto> suggestions(String query, int limit) {
        return jdbc.query(
                "select * from public.search_suggestions(?, ?)",
                SUGGESTION_MAPPER, query, limit);
    }

    /** Current dataset version; bumped by a successful import to invalidate caches. */
    public long datasetVersion() {
        Long version = jdbc.queryForObject(
                "select version from public.dataset_metadata where singleton limit 1",
                Long.class);
        return version == null ? 0L : version;
    }

    private static String toVectorLiteral(float[] embedding) {
        StringBuilder sb = new StringBuilder(embedding.length * 8);
        sb.append('[');
        for (int i = 0; i < embedding.length; i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(embedding[i]);
        }
        sb.append(']');
        return sb.toString();
    }
}
