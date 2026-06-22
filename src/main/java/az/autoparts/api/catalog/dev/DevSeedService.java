package az.autoparts.api.catalog.dev;

import java.util.List;
import java.util.Map;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.catalog.domain.Category;
import az.autoparts.api.catalog.domain.Fitment;
import az.autoparts.api.catalog.domain.FuelType;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.catalog.domain.PartNumber;
import az.autoparts.api.catalog.domain.PartNumberType;
import az.autoparts.api.catalog.domain.VehicleGeneration;
import az.autoparts.api.catalog.domain.VehicleMake;
import az.autoparts.api.catalog.domain.VehicleModel;
import az.autoparts.api.catalog.domain.VehicleVariant;
import az.autoparts.api.catalog.repo.CategoryRepository;
import az.autoparts.api.catalog.repo.FitmentRepository;
import az.autoparts.api.catalog.repo.PartNumberRepository;
import az.autoparts.api.catalog.repo.PartRepository;
import az.autoparts.api.catalog.repo.VehicleGenerationRepository;
import az.autoparts.api.catalog.repo.VehicleMakeRepository;
import az.autoparts.api.catalog.repo.VehicleModelRepository;
import az.autoparts.api.catalog.repo.VehicleVariantRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Local-only demo data loader. Wipes catalog tables and inserts a small
 * representative set so the API and frontend have something to render.
 *
 * Active only under spring.profiles.active=local; never touches production.
 */
@Service
@Profile("local")
@RequiredArgsConstructor
@Slf4j
public class DevSeedService {

    private final VehicleMakeRepository makes;
    private final VehicleModelRepository models;
    private final VehicleGenerationRepository generations;
    private final VehicleVariantRepository variants;
    private final CategoryRepository categories;
    private final PartRepository parts;
    private final PartNumberRepository partNumbers;
    private final FitmentRepository fitments;

    @Transactional
    public Map<String, Integer> reseed() {
        wipe();
        int seededVariants = seedVehicles();
        int seededCategories = seedCategories();
        int seededPartCount = seedParts();
        int seededFitmentCount = (int) fitments.count();
        int seededNumberCount = (int) partNumbers.count();

        Map<String, Integer> counts = Map.of(
            "makes", (int) makes.count(),
            "models", (int) models.count(),
            "variants", seededVariants,
            "categories", seededCategories,
            "parts", seededPartCount,
            "partNumbers", seededNumberCount,
            "fitments", seededFitmentCount
        );
        log.info("Demo catalog seeded: {}", counts);
        return counts;
    }

    private void wipe() {
        fitments.deleteAllInBatch();
        partNumbers.deleteAllInBatch();
        parts.deleteAllInBatch();
        categories.deleteAllInBatch();
        variants.deleteAllInBatch();
        generations.deleteAllInBatch();
        models.deleteAllInBatch();
        makes.deleteAllInBatch();
    }

    private int seedVehicles() {
        // ~10 makes
        VehicleMake toyota   = makes.save(make("Toyota", "toyota", 99));
        VehicleMake hyundai  = makes.save(make("Hyundai", "hyundai", 95));
        VehicleMake kia      = makes.save(make("Kia", "kia", 90));
        VehicleMake bmw      = makes.save(make("BMW", "bmw", 85));
        VehicleMake mercedes = makes.save(make("Mercedes-Benz", "mercedes-benz", 80));
        VehicleMake vw       = makes.save(make("Volkswagen", "volkswagen", 78));
        VehicleMake nissan   = makes.save(make("Nissan", "nissan", 72));
        VehicleMake honda    = makes.save(make("Honda", "honda", 65));
        VehicleMake ford     = makes.save(make("Ford", "ford", 55));
        VehicleMake lada     = makes.save(make("Lada", "lada", 50));

        // ~25 models
        VehicleModel corolla   = model(toyota, "Corolla", "corolla", 2010, 2024);
        VehicleModel camry     = model(toyota, "Camry", "camry", 2012, 2024);
        VehicleModel rav4      = model(toyota, "RAV4", "rav4", 2013, 2024);

        VehicleModel sonata    = model(hyundai, "Sonata", "sonata", 2010, 2019);
        VehicleModel elantra   = model(hyundai, "Elantra", "elantra", 2011, 2024);
        VehicleModel tucson    = model(hyundai, "Tucson", "tucson", 2015, 2024);

        VehicleModel optima    = model(kia, "Optima", "optima", 2011, 2020);
        VehicleModel sportage  = model(kia, "Sportage", "sportage", 2010, 2024);
        VehicleModel rio       = model(kia, "Rio", "rio", 2012, 2024);

        VehicleModel bmw3      = model(bmw, "3 Series", "3-series", 2011, 2024);
        VehicleModel bmw5      = model(bmw, "5 Series", "5-series", 2010, 2024);
        VehicleModel bmwX5     = model(bmw, "X5", "x5", 2013, 2024);

        VehicleModel cclass    = model(mercedes, "C-Class", "c-class", 2014, 2024);
        VehicleModel eclass    = model(mercedes, "E-Class", "e-class", 2010, 2024);

        VehicleModel passat    = model(vw, "Passat", "passat", 2010, 2024);
        VehicleModel golf      = model(vw, "Golf", "golf", 2012, 2024);
        VehicleModel tiguan    = model(vw, "Tiguan", "tiguan", 2014, 2024);

        VehicleModel altima    = model(nissan, "Altima", "altima", 2013, 2024);
        VehicleModel xtrail    = model(nissan, "X-Trail", "x-trail", 2014, 2024);

        VehicleModel civic     = model(honda, "Civic", "civic", 2012, 2024);
        VehicleModel accord    = model(honda, "Accord", "accord", 2013, 2024);

        VehicleModel focus     = model(ford, "Focus", "focus", 2011, 2018);
        VehicleModel fusion    = model(ford, "Fusion", "fusion", 2013, 2020);

        VehicleModel vesta     = model(lada, "Vesta", "vesta", 2015, 2024);
        VehicleModel niva      = model(lada, "Niva", "niva", 2010, 2024);

        // ~5 variants on a few popular models
        variants.save(variant(corolla, 2018, "1.6 SE", "2ZR-FE", "sedan", FuelType.PETROL));
        variants.save(variant(corolla, 2020, "1.8 Hybrid", "2ZR-FXE", "sedan", FuelType.HYBRID));
        variants.save(variant(camry, 2018, "2.5 SE", "A25A-FKS", "sedan", FuelType.PETROL));
        variants.save(variant(sonata, 2014, "2.4 Sport", "G4KH", "sedan", FuelType.PETROL));
        variants.save(variant(sonata, 2016, "2.0 Limited", "G4KH", "sedan", FuelType.PETROL));
        variants.save(variant(elantra, 2017, "1.6 Active", "G4FG", "sedan", FuelType.PETROL));
        variants.save(variant(optima, 2014, "2.4 EX", "G4KJ", "sedan", FuelType.PETROL));
        variants.save(variant(bmw3, 2016, "320i", "B48B20", "sedan", FuelType.PETROL));
        variants.save(variant(bmwX5, 2018, "xDrive40i", "B58B30", "SUV", FuelType.PETROL));
        variants.save(variant(passat, 2017, "1.8 TSI Comfortline", "CDAB", "sedan", FuelType.PETROL));
        variants.save(variant(altima, 2018, "2.5 SV", "QR25DE", "sedan", FuelType.PETROL));
        variants.save(variant(civic, 2019, "1.5 Turbo", "L15B7", "sedan", FuelType.PETROL));

        return (int) variants.count();
    }

    private int seedCategories() {
        // 5 roots, ~15 children = 20 categories.
        Category brakes = saveRoot("brakes",  10, "Əyləclər",     "Тормоза",         "Brakes");
        Category suspension = saveRoot("suspension", 20, "Asılma",       "Подвеска",        "Suspension");
        Category engine = saveRoot("engine", 30, "Mühərrik",      "Двигатель",       "Engine");
        Category electrical = saveRoot("electrical", 40, "Elektrik",     "Электрика",       "Electrical");
        Category body = saveRoot("body", 50, "Kuzov",        "Кузов",           "Body");

        saveChild(brakes, "brake-pads",     0, "Əyləc kolodkaları", "Тормозные колодки", "Brake pads");
        saveChild(brakes, "brake-discs",    1, "Əyləc diskləri",     "Тормозные диски",   "Brake discs");
        saveChild(brakes, "brake-fluid",    2, "Əyləc mayesi",       "Тормозная жидкость", "Brake fluid");

        saveChild(suspension, "shock-absorbers", 0, "Amortizatorlar", "Амортизаторы", "Shock absorbers");
        saveChild(suspension, "control-arms",    1, "Rıçaqlar",       "Рычаги",       "Control arms");
        saveChild(suspension, "ball-joints",     2, "Şarovo birləşmələr", "Шаровые опоры", "Ball joints");

        saveChild(engine, "oil-filters",   0, "Yağ filtrləri",      "Масляные фильтры", "Oil filters");
        saveChild(engine, "air-filters",   1, "Hava filtrləri",      "Воздушные фильтры", "Air filters");
        saveChild(engine, "spark-plugs",   2, "Şamlar",              "Свечи зажигания",   "Spark plugs");
        saveChild(engine, "timing-belts",  3, "Vaxt qayışları",      "Ремни ГРМ",         "Timing belts");

        saveChild(electrical, "batteries",     0, "Akkumulyatorlar", "Аккумуляторы", "Batteries");
        saveChild(electrical, "alternators",   1, "Generatorlar",    "Генераторы",   "Alternators");
        saveChild(electrical, "headlights",    2, "Faralar",         "Фары",         "Headlights");

        saveChild(body, "bumpers",  0, "Buferlər",       "Бамперы",       "Bumpers");
        saveChild(body, "mirrors",  1, "Güzgülər",       "Зеркала",        "Mirrors");

        return (int) categories.count();
    }

    private int seedParts() {
        Category brakePads = categories.findBySlug("brake-pads").orElseThrow();
        Category brakeDiscs = categories.findBySlug("brake-discs").orElseThrow();
        Category oilFilters = categories.findBySlug("oil-filters").orElseThrow();
        Category sparkPlugs = categories.findBySlug("spark-plugs").orElseThrow();
        Category batteries = categories.findBySlug("batteries").orElseThrow();

        VehicleVariant sonata2014 = anyVariantOf("sonata", (short) 2014);
        VehicleVariant elantra2017 = anyVariantOf("elantra", (short) 2017);
        VehicleVariant corolla2018 = anyVariantOf("corolla", (short) 2018);
        VehicleVariant camry2018 = anyVariantOf("camry", (short) 2018);
        VehicleVariant bmw3_2016 = anyVariantOf("3-series", (short) 2016);

        Part p1 = parts.save(Part.builder()
            .category(brakePads).brand("Bosch")
            .nameAz("Ön əyləc kolodkası seti — Bosch BP1635")
            .nameRu("Передние тормозные колодки — Bosch BP1635")
            .nameEn("Front brake pad set — Bosch BP1635")
            .description("Front-axle ceramic brake pad set with low-dust formulation.")
            .build());
        partNumbers.save(pn(p1, "BP1635", PartNumberType.AFTERMARKET, "Bosch"));
        partNumbers.save(pn(p1, "58101-A6A00", PartNumberType.OEM, "Hyundai"));
        fitments.save(Fitment.builder().part(p1).vehicleVariant(sonata2014).position("FRONT").build());
        fitments.save(Fitment.builder().part(p1).vehicleVariant(elantra2017).position("FRONT").build());

        Part p2 = parts.save(Part.builder()
            .category(brakeDiscs).brand("Brembo")
            .nameAz("Ön əyləc diski — Brembo 09.A187.10")
            .nameRu("Передний тормозной диск — Brembo 09.A187.10")
            .nameEn("Front brake disc — Brembo 09.A187.10")
            .description("Vented front brake disc, 320mm.")
            .build());
        partNumbers.save(pn(p2, "09.A187.10", PartNumberType.AFTERMARKET, "Brembo"));
        partNumbers.save(pn(p2, "34116855152", PartNumberType.OEM, "BMW"));
        fitments.save(Fitment.builder().part(p2).vehicleVariant(bmw3_2016).position("FRONT").build());

        Part p3 = parts.save(Part.builder()
            .category(oilFilters).brand("Mann-Filter")
            .nameAz("Yağ filtri — Mann W 712/75")
            .nameRu("Масляный фильтр — Mann W 712/75")
            .nameEn("Oil filter — Mann W 712/75")
            .description("Spin-on oil filter for 1.8/2.0 petrol engines.")
            .build());
        partNumbers.save(pn(p3, "W 712/75", PartNumberType.AFTERMARKET, "Mann-Filter"));
        partNumbers.save(pn(p3, "90915-YZZD2", PartNumberType.OEM, "Toyota"));
        fitments.save(Fitment.builder().part(p3).vehicleVariant(corolla2018).build());
        fitments.save(Fitment.builder().part(p3).vehicleVariant(camry2018).build());

        Part p4 = parts.save(Part.builder()
            .category(sparkPlugs).brand("NGK")
            .nameAz("Alışdırma şamı — NGK ILZKR7B-11S")
            .nameRu("Свеча зажигания — NGK ILZKR7B-11S")
            .nameEn("Spark plug — NGK ILZKR7B-11S")
            .description("Iridium spark plug, set of 4.")
            .build());
        partNumbers.save(pn(p4, "ILZKR7B-11S", PartNumberType.AFTERMARKET, "NGK"));
        partNumbers.save(pn(p4, "12290-5R0-A01", PartNumberType.OEM, "Honda"));

        Part p5 = parts.save(Part.builder()
            .category(batteries).brand("Varta")
            .nameAz("Akkumulyator — Varta E11 Blue Dynamic 74Ah")
            .nameRu("Аккумулятор — Varta E11 Blue Dynamic 74Ач")
            .nameEn("Battery — Varta E11 Blue Dynamic 74Ah")
            .description("12V 74Ah 680A starter battery.")
            .build());
        partNumbers.save(pn(p5, "E11", PartNumberType.AFTERMARKET, "Varta"));
        partNumbers.save(pn(p5, "5740123J", PartNumberType.OEM, "Volkswagen"));

        return (int) parts.count();
    }

    // -- helpers ------------------------------------------------------------

    private VehicleMake make(String name, String slug, int popularity) {
        return VehicleMake.builder().name(name).slug(slug).popularity(popularity).build();
    }

    private VehicleModel model(VehicleMake make, String name, String slug, int yearFrom, int yearTo) {
        VehicleModel model = models.save(VehicleModel.builder()
            .make(make).name(name).slug(slug)
            .yearFrom((short) yearFrom).yearTo((short) yearTo)
            .build());
        // Every model gets one default generation in the demo dataset. Admins
        // can later split a model into multiple generations (e.g. BMW 3 Series
        // → E46 / E90 / F30 / G20) once we have an admin UI for it.
        generations.save(VehicleGeneration.builder()
            .model(model).name(name).slug("gen")
            .yearFrom((short) yearFrom).yearTo((short) yearTo)
            .build());
        return model;
    }

    private VehicleVariant variant(VehicleModel model, int year, String trim, String engineCode, String body, FuelType fuel) {
        VehicleGeneration gen = generations.findAllByModelIdOrderByYearFromAsc(model.getId()).stream()
            .findFirst()
            .orElseThrow(() -> new IllegalStateException("No generation for model " + model.getSlug()));
        return VehicleVariant.builder()
            .generation(gen).year((short) year).trim(trim).engineCode(engineCode).bodyType(body).fuel(fuel)
            .build();
    }

    private Category saveRoot(String slug, int sortOrder, String az, String ru, String en) {
        return categories.save(Category.builder()
            .slug(slug).sortOrder(sortOrder).nameAz(az).nameRu(ru).nameEn(en).build());
    }

    private Category saveChild(Category parent, String slug, int sortOrder, String az, String ru, String en) {
        return categories.save(Category.builder()
            .parent(parent).slug(slug).sortOrder(sortOrder).nameAz(az).nameRu(ru).nameEn(en).build());
    }

    private PartNumber pn(Part part, String number, PartNumberType type, String source) {
        return PartNumber.builder().part(part).number(number).type(type).source(source).build();
    }

    private VehicleVariant anyVariantOf(String modelSlug, short year) {
        VehicleModel model = models.findAll().stream()
            .filter(m -> modelSlug.equals(m.getSlug()))
            .findFirst()
            .orElseThrow(() -> new IllegalStateException("Model not found: " + modelSlug));
        List<VehicleVariant> matches = variants.findAllByModelIdAndYearOrderByTrimAsc(model.getId(), year);
        if (matches.isEmpty()) throw new IllegalStateException("No variant for " + modelSlug + " " + year);
        return matches.get(0);
    }
}
