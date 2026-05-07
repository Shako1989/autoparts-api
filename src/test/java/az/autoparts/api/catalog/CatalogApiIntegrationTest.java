package az.autoparts.api.catalog;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.nullValue;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import az.autoparts.api.catalog.domain.Category;
import az.autoparts.api.catalog.domain.Fitment;
import az.autoparts.api.catalog.domain.FuelType;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.catalog.domain.PartNumber;
import az.autoparts.api.catalog.domain.PartNumberType;
import az.autoparts.api.catalog.domain.VehicleMake;
import az.autoparts.api.catalog.domain.VehicleModel;
import az.autoparts.api.catalog.domain.VehicleVariant;
import az.autoparts.api.catalog.repo.CategoryRepository;
import az.autoparts.api.catalog.repo.FitmentRepository;
import az.autoparts.api.catalog.repo.PartNumberRepository;
import az.autoparts.api.catalog.repo.PartRepository;
import az.autoparts.api.catalog.repo.VehicleMakeRepository;
import az.autoparts.api.catalog.repo.VehicleModelRepository;
import az.autoparts.api.catalog.repo.VehicleVariantRepository;

import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

@Testcontainers
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class CatalogApiIntegrationTest {

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

    @Autowired VehicleMakeRepository makes;
    @Autowired VehicleModelRepository models;
    @Autowired VehicleVariantRepository variants;
    @Autowired CategoryRepository categories;
    @Autowired PartRepository parts;
    @Autowired PartNumberRepository partNumbers;
    @Autowired FitmentRepository fitments;

    UUID modelSonataId;
    UUID variantSonataId;
    UUID categoryBrakePadsId;
    UUID partBoschId;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;

        // Wipe in case the container is reused across tests in the same class run.
        fitments.deleteAll();
        partNumbers.deleteAll();
        parts.deleteAll();
        categories.deleteAll();
        variants.deleteAll();
        models.deleteAll();
        makes.deleteAll();

        VehicleMake hyundai = makes.save(VehicleMake.builder().name("Hyundai").slug("hyundai").popularity(95).build());
        makes.save(VehicleMake.builder().name("Kia").slug("kia").popularity(80).build());

        VehicleModel sonata = models.save(VehicleModel.builder()
            .make(hyundai).name("Sonata").slug("sonata").yearFrom((short) 2010).yearTo((short) 2019).build());
        modelSonataId = sonata.getId();

        VehicleVariant sonata2014 = variants.save(VehicleVariant.builder()
            .model(sonata).year((short) 2014).trim("Sport").engineCode("G4KH").bodyType("sedan").fuel(FuelType.PETROL)
            .build());
        variantSonataId = sonata2014.getId();

        Category brakes = categories.save(Category.builder()
            .slug("brakes").nameAz("Əyləclər").nameRu("Тормоза").nameEn("Brakes").sortOrder(10).build());
        Category brakePads = categories.save(Category.builder()
            .parent(brakes).slug("brake-pads").nameAz("Əyləc kolodkası").nameRu("Тормозные колодки").nameEn("Brake pads").sortOrder(0).build());
        categoryBrakePadsId = brakePads.getId();

        Part bosch = parts.save(Part.builder()
            .category(brakePads)
            .nameAz("Ön əyləc kolodkası").nameRu("Передние колодки").nameEn("Front brake pad")
            .brand("Bosch").description("Replacement front pads")
            .build());
        partBoschId = bosch.getId();

        partNumbers.save(PartNumber.builder().part(bosch).number("BP1635").type(PartNumberType.AFTERMARKET).source("Bosch").build());
        partNumbers.save(PartNumber.builder().part(bosch).number("58101-A6A00").type(PartNumberType.OEM).source("Hyundai").build());

        fitments.save(Fitment.builder().part(bosch).vehicleVariant(sonata2014).position("FRONT").build());
    }

    @Test
    void list_makes_returns_makes_sorted_by_popularity() {
        given().when().get("/api/v1/catalog/makes")
            .then().statusCode(200)
            .body("size()", greaterThan(0))
            .body("[0].slug", equalTo("hyundai"))
            .body("[1].slug", equalTo("kia"));
    }

    @Test
    void list_models_for_make_slug() {
        given().when().get("/api/v1/catalog/makes/hyundai/models")
            .then().statusCode(200)
            .body("size()", is(1))
            .body("[0].slug", equalTo("sonata"));
    }

    @Test
    void unknown_make_slug_returns_404_problem_detail() {
        given().when().get("/api/v1/catalog/makes/nonexistent/models")
            .then().statusCode(404)
            .contentType(ContentType.JSON)
            .body("title", equalTo("Resource not found"));
    }

    @Test
    void list_years_for_model() {
        given().when().get("/api/v1/catalog/models/{modelId}/years", modelSonataId)
            .then().statusCode(200)
            .body("$", contains(2014));
    }

    @Test
    void list_variants_for_model_and_year() {
        given()
            .queryParam("model", modelSonataId.toString())
            .queryParam("year", 2014)
            .when().get("/api/v1/catalog/variants")
            .then().statusCode(200)
            .body("size()", is(1))
            .body("[0].trim", equalTo("Sport"))
            .body("[0].engineCode", equalTo("G4KH"))
            .body("[0].fuel", equalTo("PETROL"));
    }

    @Test
    void category_tree_returns_hierarchy_localised_in_az_by_default() {
        given().when().get("/api/v1/catalog/categories")
            .then().statusCode(200)
            .body("size()", is(1))
            .body("[0].slug", equalTo("brakes"))
            .body("[0].name", equalTo("Əyləclər"))
            .body("[0].children.size()", is(1))
            .body("[0].children[0].slug", equalTo("brake-pads"));
    }

    @Test
    void category_tree_localises_to_russian_when_accept_language_is_ru() {
        given().header("Accept-Language", "ru-RU,ru;q=0.9")
            .when().get("/api/v1/catalog/categories")
            .then().statusCode(200)
            .body("[0].name", equalTo("Тормоза"))
            .body("[0].children[0].name", equalTo("Тормозные колодки"));
    }

    @Test
    void category_by_slug_returns_breadcrumbs_in_root_to_leaf_order() {
        given().header("Accept-Language", "en")
            .when().get("/api/v1/catalog/categories/brake-pads")
            .then().statusCode(200)
            .body("name", equalTo("Brake pads"))
            .body("breadcrumbs.slug", contains("brakes", "brake-pads"))
            .body("breadcrumbs.name", contains("Brakes", "Brake pads"));
    }

    @Test
    void unknown_category_slug_is_404() {
        given().when().get("/api/v1/catalog/categories/no-such")
            .then().statusCode(404);
    }

    @Test
    void part_endpoint_returns_localised_name_brand_and_part_numbers() {
        given().header("Accept-Language", "en")
            .when().get("/api/v1/catalog/parts/{partId}", partBoschId)
            .then().statusCode(200)
            .body("name", equalTo("Front brake pad"))
            .body("brand", equalTo("Bosch"))
            .body("categorySlug", equalTo("brake-pads"))
            .body("partNumbers.size()", is(2))
            .body("partNumbers.number", containsInAnyOrder("BP1635", "58101-A6A00"))
            .body("partNumbers.type", hasItem("OEM"));
    }

    @Test
    void unknown_part_id_is_404() {
        given().when().get("/api/v1/catalog/parts/{partId}", UUID.randomUUID())
            .then().statusCode(404);
    }

    @Test
    void part_fitments_endpoint_lists_compatible_vehicles() {
        given().when().get("/api/v1/catalog/parts/{partId}/fitments", partBoschId)
            .then().statusCode(200)
            .body("$", hasSize(1))
            .body("[0].makeName", equalTo("Hyundai"))
            .body("[0].modelName", equalTo("Sonata"))
            .body("[0].year", is(2014))
            .body("[0].position", equalTo("FRONT"))
            .body("[0].notes", nullValue());
    }
}
