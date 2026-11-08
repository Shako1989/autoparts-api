package az.autoparts.api.catalog;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import az.autoparts.api.catalog.domain.FuelType;
import az.autoparts.api.catalog.domain.VehicleGeneration;
import az.autoparts.api.catalog.domain.VehicleMake;
import az.autoparts.api.catalog.domain.VehicleModel;
import az.autoparts.api.catalog.domain.VehicleVariant;
import az.autoparts.api.catalog.repo.FitmentRepository;
import az.autoparts.api.catalog.repo.VehicleGenerationRepository;
import az.autoparts.api.catalog.repo.VehicleMakeRepository;
import az.autoparts.api.catalog.repo.VehicleModelRepository;
import az.autoparts.api.catalog.repo.VehicleVariantRepository;
import az.autoparts.api.catalog.service.vpic.VpicClient;
import az.autoparts.api.catalog.service.vpic.VpicDecodeResult;
import az.autoparts.api.common.error.UpstreamUnavailableException;
import io.restassured.RestAssured;

/**
 * End-to-end test of GET /api/v1/catalog/vin/{vin} against a real Postgres.
 * The NHTSA call itself is mocked; VpicRestClientTest covers the HTTP layer.
 */
@Testcontainers
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class VinLookupApiIntegrationTest {

    private static final String FUSION_VIN = "3FA6P0LU4KR123456";
    private static final String BMW_VIN = "WBA8E9C50GK123456";

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
        // No Redis in this test; keep the cache abstraction on but in-memory.
        registry.add("spring.cache.type", () -> "simple");
    }

    @MockitoBean VpicClient vpic;

    @LocalServerPort int port;

    @Autowired VehicleMakeRepository makes;
    @Autowired VehicleModelRepository models;
    @Autowired VehicleGenerationRepository generations;
    @Autowired VehicleVariantRepository variants;
    @Autowired FitmentRepository fitments;

    UUID fusionSeHybridId;
    UUID bmw328iId;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;

        fitments.deleteAll();
        variants.deleteAll();
        generations.deleteAll();
        models.deleteAll();
        makes.deleteAll();

        VehicleMake ford = makes.save(VehicleMake.builder().name("Ford").slug("ford").popularity(50).build());
        VehicleModel fusion = models.save(VehicleModel.builder()
            .make(ford).name("Fusion").slug("fusion").yearFrom((short) 2013).yearTo((short) 2020).build());
        VehicleGeneration fusionGen = generations.save(VehicleGeneration.builder()
            .model(fusion).name("Fusion").slug("gen").yearFrom((short) 2013).yearTo((short) 2020).build());
        variants.save(variant(fusionGen, 2019, "SE", "1.5 EcoBoost", FuelType.PETROL));
        fusionSeHybridId = variants.save(variant(fusionGen, 2019, "SE Hybrid", "2.0 Atkinson HEV", FuelType.HYBRID)).getId();
        variants.save(variant(fusionGen, 2019, "Titanium", "2.0 EcoBoost", FuelType.PETROL));

        VehicleMake bmw = makes.save(VehicleMake.builder().name("BMW").slug("bmw").popularity(90).build());
        VehicleModel threeSeries = models.save(VehicleModel.builder()
            .make(bmw).name("3 Series").slug("3-series").yearFrom((short) 1990).build());
        VehicleGeneration f30 = generations.save(VehicleGeneration.builder()
            .model(threeSeries).code("F30").name("3 Series F30").slug("f30").yearFrom((short) 2012).yearTo((short) 2019).build());
        variants.save(variant(f30, 2016, "320d", "B47D20", FuelType.DIESEL));
        bmw328iId = variants.save(variant(f30, 2016, "328i", "N20B20", FuelType.PETROL)).getId();
    }

    @Test
    void decodes_and_matches_a_us_market_vin_to_one_variant() {
        when(vpic.decode(FUSION_VIN, null)).thenReturn(fusionHybrid());

        given().when().get("/api/v1/catalog/vin/" + FUSION_VIN)
            .then().statusCode(200)
            .body("vin", equalTo(FUSION_VIN))
            .body("status", equalTo("EXACT"))
            .body("decoded.make", equalTo("FORD"))
            .body("decoded.model", equalTo("Fusion"))
            .body("decoded.year", equalTo(2019))
            .body("decoded.engine.cylinders", equalTo(4))
            .body("match.make.slug", equalTo("ford"))
            .body("match.model.slug", equalTo("fusion"))
            .body("match.generation.slug", equalTo("gen"))
            .body("match.fuel", equalTo("HYBRID"))
            .body("match.bodyType", equalTo("sedan"))
            .body("match.variants", hasSize(1))
            .body("match.variants[0].id", equalTo(fusionSeHybridId.toString()))
            .body("match.variants[0].trim", equalTo("SE Hybrid"));
    }

    @Test
    void accepts_lowercase_input_and_a_masked_serial_with_a_year_hint() {
        when(vpic.decode("3FA6P0LU4KR******", 2019)).thenReturn(fusionHybrid());

        given().queryParam("year", 2019)
            .when().get("/api/v1/catalog/vin/3fa6p0lu4kr******")
            .then().statusCode(200)
            .body("vin", equalTo("3FA6P0LU4KR******"))
            .body("status", equalTo("EXACT"));
    }

    @Test
    void bmw_vin_is_filed_under_the_series_model_through_the_variant_trim() {
        when(vpic.decode(BMW_VIN, null)).thenReturn(decode("BMW", "328i", 2016, "3-Series", null, "Sedan/Saloon",
            new BigDecimal("2.0"), "Gasoline", null, null, "0"));

        given().when().get("/api/v1/catalog/vin/" + BMW_VIN)
            .then().statusCode(200)
            .body("status", equalTo("EXACT"))
            .body("match.model.slug", equalTo("3-series"))
            .body("match.generation.code", equalTo("F30"))
            .body("match.variants", hasSize(1))
            .body("match.variants[0].id", equalTo(bmw328iId.toString()));
    }

    @Test
    void contradicting_catalog_data_yields_model_only_instead_of_a_wrong_exact_match() {
        // vPIC: 2016 335i petrol 3.0. Catalog for 2016: 320d (diesel) and 328i (petrol, other designation).
        when(vpic.decode(BMW_VIN, null)).thenReturn(decode("BMW", "335i", 2016, "3-Series", null, "Sedan/Saloon",
            new BigDecimal("3.0"), "Gasoline", null, null, "0"));

        given().when().get("/api/v1/catalog/vin/" + BMW_VIN)
            .then().statusCode(200)
            .body("status", equalTo("MODEL_ONLY"))
            .body("match.model.slug", equalTo("3-series"))
            .body("match.generation.code", equalTo("F30"))
            .body("match.variants", hasSize(0));
    }

    @Test
    void undecodable_vin_returns_200_with_not_decoded_status() {
        when(vpic.decode(anyString(), any()))
            .thenReturn(decode(null, null, null, null, null, null, null, null, null, null, "8"));

        given().when().get("/api/v1/catalog/vin/XTA217030F0123456")
            .then().statusCode(200)
            .body("status", equalTo("NOT_DECODED"))
            .body("decoded.make", nullValue())
            .body("decoded.errorCode", equalTo("8"))
            .body("match.make", nullValue())
            .body("match.variants", hasSize(0));
    }

    @Test
    void malformed_vin_returns_400_problem_detail_without_calling_the_decoder() {
        given().when().get("/api/v1/catalog/vin/ABC123")
            .then().statusCode(400)
            .body("title", equalTo("Bad request"))
            .body("detail", containsString("17 characters"));

        verify(vpic, never()).decode(anyString(), any());
    }

    @Test
    void decoder_outage_returns_503_problem_detail() {
        when(vpic.decode(anyString(), any()))
            .thenThrow(new UpstreamUnavailableException("VIN decoder (NHTSA vPIC) is unavailable", null));

        given().when().get("/api/v1/catalog/vin/" + FUSION_VIN)
            .then().statusCode(503)
            .body("title", equalTo("Upstream service unavailable"))
            .body("type", equalTo("https://autoparts.az/problems/upstream-unavailable"));
    }

    // --- fixtures -----------------------------------------------------------

    private static VpicDecodeResult fusionHybrid() {
        return decode("FORD", "Fusion", 2019, null, "SE Hybrid", "Sedan/Saloon", new BigDecimal("2.0"),
            "Gasoline", "Electric", "Strong HEV (Hybrid Electric Vehicle)", "0");
    }

    private static VpicDecodeResult decode(
        String make, String model, Integer year, String series, String trim, String bodyClass,
        BigDecimal displacement, String fuelPrimary, String fuelSecondary, String electrification, String errorCode
    ) {
        return new VpicDecodeResult(null, make, null, null, model, null, year, series, trim, bodyClass,
            make == null ? null : "PASSENGER CAR", null, displacement, make == null ? null : 4, null, null,
            fuelPrimary, fuelSecondary, electrification, null, errorCode, null);
    }

    private static VehicleVariant variant(
        VehicleGeneration gen, int year, String trim, String engineCode, FuelType fuel
    ) {
        return VehicleVariant.builder().generation(gen).year((short) year).trim(trim)
            .engineCode(engineCode).bodyType("sedan").fuel(fuel).build();
    }
}
