package az.autoparts.api.listings;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.nullValue;

import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import io.restassured.RestAssured;

@Testcontainers
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class ListingsApiIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(DockerImageName.parse("postgres:16"));

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.flyway.url", postgres::getJdbcUrl);
        registry.add("spring.flyway.user", postgres::getUsername);
        registry.add("spring.flyway.password", postgres::getPassword);
        registry.add("app.cors.allowed-origins", () -> "http://localhost:5173");
    }

    @LocalServerPort int port;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
    }

    @Test
    void batch_listing_stats_keep_request_order_and_report_zero_for_parts_without_offers() {
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();

        given().queryParam("ids", a + "," + b + "," + a)
            .when().get("/api/v1/parts/listings-summary")
            .then().statusCode(200)
            .body("size()", is(2))
            .body("[0].partId", equalTo(a.toString()))
            .body("[0].activeCount", is(0))
            .body("[0].minPriceMinor", nullValue())
            .body("[0].currency", nullValue())
            .body("[1].partId", equalTo(b.toString()));
    }

    @Test
    void batch_listing_stats_refuse_more_than_a_hundred_ids() {
        String ids = Stream.generate(UUID::randomUUID).limit(101)
            .map(UUID::toString)
            .collect(Collectors.joining(","));

        given().queryParam("ids", ids)
            .when().get("/api/v1/parts/listings-summary")
            .then().statusCode(400);
    }
}
