package com.example.vehiclesearch.model;

import com.example.vehiclesearch.dto.MatchType;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Domain model for a vehicle listing as returned by the search SQL functions.
 * This is the persistence-layer representation; the service maps it to
 * {@link com.example.vehiclesearch.dto.SearchItemDto} for the HTTP response,
 * keeping the domain model independent of the wire format.
 */
public class VehicleListing {

    private long id;
    private Integer year;
    private String make;
    private String model;
    private String trim;
    private String body;
    private String transmission;
    private String vin;
    private String state;
    private BigDecimal conditionScore;
    private Long odometer;
    private String color;
    private String interior;
    private String seller;
    private BigDecimal mmr;
    private BigDecimal sellingPrice;
    private OffsetDateTime saleDate;
    private MatchType matchType;
    private float score;
    private boolean hasNext;
    private double elapsedMs;

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public Integer getYear() {
        return year;
    }

    public void setYear(Integer year) {
        this.year = year;
    }

    public String getMake() {
        return make;
    }

    public void setMake(String make) {
        this.make = make;
    }

    public String getModel() {
        return model;
    }

    public void setModel(String model) {
        this.model = model;
    }

    public String getTrim() {
        return trim;
    }

    public void setTrim(String trim) {
        this.trim = trim;
    }

    public String getBody() {
        return body;
    }

    public void setBody(String body) {
        this.body = body;
    }

    public String getTransmission() {
        return transmission;
    }

    public void setTransmission(String transmission) {
        this.transmission = transmission;
    }

    public String getVin() {
        return vin;
    }

    public void setVin(String vin) {
        this.vin = vin;
    }

    public String getState() {
        return state;
    }

    public void setState(String state) {
        this.state = state;
    }

    public BigDecimal getConditionScore() {
        return conditionScore;
    }

    public void setConditionScore(BigDecimal conditionScore) {
        this.conditionScore = conditionScore;
    }

    public Long getOdometer() {
        return odometer;
    }

    public void setOdometer(Long odometer) {
        this.odometer = odometer;
    }

    public String getColor() {
        return color;
    }

    public void setColor(String color) {
        this.color = color;
    }

    public String getInterior() {
        return interior;
    }

    public void setInterior(String interior) {
        this.interior = interior;
    }

    public String getSeller() {
        return seller;
    }

    public void setSeller(String seller) {
        this.seller = seller;
    }

    public BigDecimal getMmr() {
        return mmr;
    }

    public void setMmr(BigDecimal mmr) {
        this.mmr = mmr;
    }

    public BigDecimal getSellingPrice() {
        return sellingPrice;
    }

    public void setSellingPrice(BigDecimal sellingPrice) {
        this.sellingPrice = sellingPrice;
    }

    public OffsetDateTime getSaleDate() {
        return saleDate;
    }

    public void setSaleDate(OffsetDateTime saleDate) {
        this.saleDate = saleDate;
    }

    public MatchType getMatchType() {
        return matchType;
    }

    public void setMatchType(MatchType matchType) {
        this.matchType = matchType;
    }

    public float getScore() {
        return score;
    }

    public void setScore(float score) {
        this.score = score;
    }

    public boolean isHasNext() {
        return hasNext;
    }

    public void setHasNext(boolean hasNext) {
        this.hasNext = hasNext;
    }

    public double getElapsedMs() {
        return elapsedMs;
    }

    public void setElapsedMs(double elapsedMs) {
        this.elapsedMs = elapsedMs;
    }
}
