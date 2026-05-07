package az.autoparts.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase.Replace;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
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
import az.autoparts.api.common.auditing.JpaAuditingConfig;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

@Testcontainers
@DataJpaTest
@AutoConfigureTestDatabase(replace = Replace.NONE)
@Import(JpaAuditingConfig.class)
class CatalogPersistenceIntegrationTest {

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
    }

    @Autowired VehicleMakeRepository makes;
    @Autowired VehicleModelRepository models;
    @Autowired VehicleVariantRepository variants;
    @Autowired CategoryRepository categories;
    @Autowired PartRepository parts;
    @Autowired PartNumberRepository partNumbers;
    @Autowired FitmentRepository fitments;
    @Autowired EntityManager em;

    @Test
    void vehicle_taxonomy_round_trips() {
        VehicleMake hyundai = makes.save(VehicleMake.builder()
            .name("Hyundai").slug("hyundai").popularity(95).build());

        VehicleModel sonata = models.save(VehicleModel.builder()
            .make(hyundai).name("Sonata").slug("sonata").yearFrom((short) 2010).yearTo((short) 2019).build());

        VehicleVariant variant = variants.save(VehicleVariant.builder()
            .model(sonata).year((short) 2014).trim("Sport").engineCode("G4KH").bodyType("sedan").fuel(FuelType.PETROL).build());

        em.flush();
        em.clear();

        assertThat(makes.findBySlug("hyundai")).isPresent();
        assertThat(models.findByMakeIdAndSlug(hyundai.getId(), "sonata")).isPresent();
        assertThat(variants.findDistinctYearsByModelId(sonata.getId())).containsExactly((short) 2014);
        assertThat(variants.findById(variant.getId())).isPresent();
    }

    @Test
    void category_self_reference_works() {
        Category brakes = categories.save(Category.builder()
            .slug("brakes").nameAz("Əyləclər").nameRu("Тормоза").nameEn("Brakes").sortOrder(10).build());

        Category brakesFront = categories.save(Category.builder()
            .parent(brakes).slug("brakes-front").nameAz("Ön əyləclər").nameRu("Передние тормоза").nameEn("Front brakes").sortOrder(0).build());

        em.flush();
        em.clear();

        List<Category> children = categories.findAllByParentIdOrderBySortOrderAsc(brakes.getId());
        assertThat(children).hasSize(1);
        assertThat(children.get(0).getSlug()).isEqualTo("brakes-front");
        assertThat(categories.findAllByParentIsNullOrderBySortOrderAsc()).extracting(Category::getSlug).contains("brakes");
    }

    @Test
    void part_with_localised_names_and_part_numbers() {
        Category brakePads = categories.save(Category.builder()
            .slug("brake-pads").nameAz("Əyləc kolodkaları").nameRu("Тормозные колодки").nameEn("Brake pads").sortOrder(0).build());

        Part part = parts.save(Part.builder()
            .category(brakePads)
            .nameAz("Ön əyləc kolodkası").nameRu("Передние тормозные колодки").nameEn("Front brake pad")
            .brand("Bosch").description("Replacement pads")
            .build());

        partNumbers.save(PartNumber.builder().part(part).number("BP1635").type(PartNumberType.AFTERMARKET).source("Bosch").build());
        partNumbers.save(PartNumber.builder().part(part).number("58101-A6A00").type(PartNumberType.OEM).source("Hyundai").build());

        em.flush();
        em.clear();

        Part loaded = parts.findWithCategoryById(part.getId()).orElseThrow();
        assertThat(loaded.getNameAz()).isEqualTo("Ön əyləc kolodkası");
        assertThat(loaded.getCategory().getSlug()).isEqualTo("brake-pads");
        assertThat(partNumbers.findAllByNumber("BP1635")).hasSize(1);
        assertThat(partNumbers.findAllByPartId(part.getId())).hasSize(2);
    }

    @Test
    void fitment_links_part_to_variant() {
        VehicleMake make = makes.save(VehicleMake.builder().name("Kia").slug("kia").build());
        VehicleModel model = models.save(VehicleModel.builder().make(make).name("Optima").slug("optima").yearFrom((short) 2011).build());
        VehicleVariant variant = variants.save(VehicleVariant.builder().model(model).year((short) 2014).fuel(FuelType.PETROL).build());

        Category cat = categories.save(Category.builder()
            .slug("brake-pads-fit").nameAz("X").nameRu("X").nameEn("X").sortOrder(0).build());
        Part part = parts.save(Part.builder().category(cat).nameAz("X").nameRu("X").nameEn("X").build());

        fitments.save(Fitment.builder().part(part).vehicleVariant(variant).position("FRONT").build());
        em.flush();
        em.clear();

        List<Fitment> byPart = fitments.findAllByPartId(part.getId());
        assertThat(byPart).hasSize(1);
        assertThat(byPart.get(0).getVehicleVariant().getModel().getMake().getSlug()).isEqualTo("kia");
    }

    @Test
    void unique_constraint_on_make_slug_fires() {
        makes.saveAndFlush(VehicleMake.builder().name("Toyota").slug("toyota").build());
        assertThatThrownBy(() ->
            makes.saveAndFlush(VehicleMake.builder().name("Toyota Motor").slug("toyota").build())
        ).isInstanceOf(DataIntegrityViolationException.class);
    }
}
