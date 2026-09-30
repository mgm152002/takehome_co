package com.example.vehiclesearch;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(
        classes = SearchApplication.class,
        properties = "spring.autoconfigure.exclude=org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration")
class SearchApplicationTest {

    @Test
    void applicationContextLoads() {
    }
}
