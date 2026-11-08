package az.autoparts.api.catalog.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyShort;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import az.autoparts.api.catalog.api.dto.VehicleVariantResponse;
import az.autoparts.api.catalog.api.dto.VinLookupResponse;
import az.autoparts.api.catalog.api.dto.VinLookupResponse.MatchStatus;
import az.autoparts.api.catalog.api.mapper.VehicleMapperImpl;
import az.autoparts.api.catalog.domain.FuelType;
import az.autoparts.api.catalog.domain.VehicleGeneration;
import az.autoparts.api.catalog.domain.VehicleMake;
import az.autoparts.api.catalog.domain.VehicleModel;
import az.autoparts.api.catalog.domain.VehicleVariant;
import az.autoparts.api.catalog.repo.VehicleGenerationRepository;
import az.autoparts.api.catalog.repo.VehicleMakeRepository;
import az.autoparts.api.catalog.repo.VehicleModelRepository;
import az.autoparts.api.catalog.repo.VehicleVariantRepository;
import az.autoparts.api.catalog.service.vpic.VpicClient;
import az.autoparts.api.catalog.service.vpic.VpicDecodeResult;
import az.autoparts.api.common.error.BadRequestException;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class VinLookupServiceImplTest {

    private static final String FUSION_VIN = "3FA6P0LU4KR123456";
    private static final String BMW_VIN = "WBA8E9C50GK123456";

    @Mock VpicClient vpic;
    @Mock VehicleMakeRepository makes;
    @Mock VehicleModelRepository models;
    @Mock VehicleGenerationRepository generations;
    @Mock VehicleVariantRepository variants;

    VinLookupServiceImpl service;

    VehicleMake ford;
    VehicleMake bmw;
    VehicleModel fusion;
    VehicleModel threeSeries;
    VehicleGeneration fusionGen;
    VehicleGeneration f30;
    VehicleVariant fusionSe;
    VehicleVariant fusionSeHybrid;
    VehicleVariant fusionTitanium;
    VehicleVariant bmw320d;
    VehicleVariant bmw328i;

    @BeforeEach
    void setUp() {
        service = new VinLookupServiceImpl(vpic, makes, models, generations, variants, new VehicleMapperImpl());

        ford = make("Ford", "ford");
        fusion = model(ford, "Fusion", "fusion", 2013, 2020);
        fusionGen = generation(fusion, null, "Fusion", "gen", 2013, 2020);
        fusionSe = variant(fusionGen, 2019, "SE", "1.5 EcoBoost", "sedan", FuelType.PETROL);
        fusionSeHybrid = variant(fusionGen, 2019, "SE Hybrid", "2.0 Atkinson HEV", "sedan", FuelType.HYBRID);
        fusionTitanium = variant(fusionGen, 2019, "Titanium", "2.0 EcoBoost", "sedan", FuelType.PETROL);

        bmw = make("BMW", "bmw");
        threeSeries = model(bmw, "3 Series", "3-series", 1990, null);
        f30 = generation(threeSeries, "F30", "3 Series F30", "f30", 2012, 2019);
        bmw320d = variant(f30, 2016, "320d", "B47D20", "sedan", FuelType.DIESEL);
        bmw328i = variant(f30, 2016, "328i", "N20B20", "sedan", FuelType.PETROL);

        // Default: the catalog knows nothing. Tests add what they need.
        when(makes.findByNameIgnoreCase(anyString())).thenReturn(Optional.empty());
        when(makes.findBySlug(anyString())).thenReturn(Optional.empty());
        when(models.findAllByMakeIdAndNameIgnoreCase(any(), anyString())).thenReturn(List.of());
        when(models.findByMakeIdAndSlug(any(), anyString())).thenReturn(Optional.empty());
        when(variants.findAllByMakeIdAndTrimIgnoreCase(any(), anyString())).thenReturn(List.of());
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(any(), anyShort())).thenReturn(List.of());
        when(generations.findAllByModelIdOrderByYearFromAsc(any())).thenReturn(List.of());
    }

    private void catalogKnowsFord2019() {
        when(makes.findByNameIgnoreCase("FORD")).thenReturn(Optional.of(ford));
        when(models.findAllByMakeIdAndNameIgnoreCase(ford.getId(), "Fusion")).thenReturn(List.of(fusion));
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(fusion.getId(), (short) 2019))
            .thenReturn(List.of(fusionSe, fusionSeHybrid, fusionTitanium));
        when(generations.findAllByModelIdOrderByYearFromAsc(fusion.getId())).thenReturn(List.of(fusionGen));
    }

    @Test
    void hybrid_fusion_resolves_to_the_single_hybrid_variant() {
        catalogKnowsFord2019();
        when(vpic.decode(FUSION_VIN, null)).thenReturn(
            fusion(2019, "SE Hybrid", new BigDecimal("2.0"), "Gasoline", "Electric", "Strong HEV (Hybrid Electric Vehicle)"));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.EXACT);
        assertThat(r.match().variants()).extracting(VehicleVariantResponse::id).containsExactly(fusionSeHybrid.getId());
        assertThat(r.match().model().slug()).isEqualTo("fusion");
        assertThat(r.match().generation().id()).isEqualTo(fusionGen.getId());
        assertThat(r.match().fuel()).isEqualTo(FuelType.HYBRID);
        assertThat(r.match().bodyType()).isEqualTo("sedan");
        assertThat(r.decoded().trim()).isEqualTo("SE Hybrid");
        assertThat(r.decoded().engine().displacementL()).isEqualByComparingTo("2.0");
    }

    @Test
    void petrol_fusion_without_trim_or_displacement_stays_ambiguous() {
        catalogKnowsFord2019();
        when(vpic.decode(FUSION_VIN, null)).thenReturn(fusion(2019, null, null, "Gasoline", null, null));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.AMBIGUOUS);
        assertThat(r.match().variants()).extracting(VehicleVariantResponse::id)
            .containsExactlyInAnyOrder(fusionSe.getId(), fusionTitanium.getId());
        assertThat(r.match().generation()).as("all candidates share one generation").isNotNull();
    }

    @Test
    void displacement_in_engine_code_breaks_a_tie_between_petrol_variants() {
        catalogKnowsFord2019();
        when(vpic.decode(FUSION_VIN, null)).thenReturn(fusion(2019, null, new BigDecimal("2.0"), "Gasoline", null, null));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.EXACT);
        assertThat(r.match().variants()).extracting(VehicleVariantResponse::id).containsExactly(fusionTitanium.getId());
    }

    @Test
    void a_narrowing_step_that_would_empty_the_list_is_skipped() {
        catalogKnowsFord2019();
        // Trim "Platinum" matches nothing; fuel + displacement still narrow to Titanium.
        when(vpic.decode(FUSION_VIN, null)).thenReturn(
            fusion(2019, "Platinum", new BigDecimal("2.0"), "Gasoline", null, null));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.EXACT);
        assertThat(r.match().variants()).extracting(VehicleVariantResponse::id).containsExactly(fusionTitanium.getId());
    }

    @Test
    void bmw_model_name_is_resolved_through_a_variant_trim() {
        when(makes.findByNameIgnoreCase("BMW")).thenReturn(Optional.of(bmw));
        when(variants.findAllByMakeIdAndTrimIgnoreCase(bmw.getId(), "328i")).thenReturn(List.of(bmw328i));
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(threeSeries.getId(), (short) 2016))
            .thenReturn(List.of(bmw320d, bmw328i));
        when(vpic.decode(BMW_VIN, null)).thenReturn(
            decode("BMW", "328i", 2016, null, null, "Sedan/Saloon", new BigDecimal("2.0"), "Gasoline", null, null));

        VinLookupResponse r = service.lookup(BMW_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.EXACT);
        assertThat(r.match().model().slug()).isEqualTo("3-series");
        assertThat(r.match().generation().code()).isEqualTo("F30");
        assertThat(r.match().variants()).extracting(VehicleVariantResponse::id).containsExactly(bmw328i.getId());
    }

    @Test
    void fuel_contradiction_drops_the_only_candidate_and_yields_model_only() {
        when(makes.findByNameIgnoreCase("BMW")).thenReturn(Optional.of(bmw));
        when(models.findByMakeIdAndSlug(bmw.getId(), "3-series")).thenReturn(Optional.of(threeSeries));
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(threeSeries.getId(), (short) 2016))
            .thenReturn(List.of(bmw320d));
        when(generations.findAllByModelIdOrderByYearFromAsc(threeSeries.getId())).thenReturn(List.of(f30));
        when(vpic.decode(BMW_VIN, null)).thenReturn(
            decode("BMW", "328i", 2016, "3-Series", null, "Sedan/Saloon", new BigDecimal("2.0"), "Gasoline", null, null));

        VinLookupResponse r = service.lookup(BMW_VIN, null);

        assertThat(r.status()).as("a diesel 320d must not be returned for a petrol 328i").isEqualTo(MatchStatus.MODEL_ONLY);
        assertThat(r.match().variants()).isEmpty();
        assertThat(r.match().model().slug()).as("model resolved through vPIC's series field").isEqualTo("3-series");
        assertThat(r.match().generation().code()).as("generation from the year range").isEqualTo("F30");
    }

    @Test
    void designation_style_model_names_must_equal_the_variant_trim() {
        when(makes.findByNameIgnoreCase("BMW")).thenReturn(Optional.of(bmw));
        when(models.findByMakeIdAndSlug(bmw.getId(), "3-series")).thenReturn(Optional.of(threeSeries));
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(threeSeries.getId(), (short) 2016))
            .thenReturn(List.of(bmw320d, bmw328i));
        when(generations.findAllByModelIdOrderByYearFromAsc(threeSeries.getId())).thenReturn(List.of(f30));
        when(vpic.decode(BMW_VIN, null)).thenReturn(
            decode("BMW", "335i", 2016, "3-Series", null, "Sedan/Saloon", new BigDecimal("3.0"), "Gasoline", null, null));

        VinLookupResponse r = service.lookup(BMW_VIN, null);

        assertThat(r.status()).as("328i is petrol but a different designation than 335i").isEqualTo(MatchStatus.MODEL_ONLY);
        assertThat(r.match().variants()).isEmpty();
        assertThat(r.match().generation().code()).isEqualTo("F30");
    }

    @Test
    void displacement_contradiction_drops_the_only_candidate() {
        when(makes.findByNameIgnoreCase("FORD")).thenReturn(Optional.of(ford));
        when(models.findAllByMakeIdAndNameIgnoreCase(ford.getId(), "Fusion")).thenReturn(List.of(fusion));
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(fusion.getId(), (short) 2019)).thenReturn(List.of(fusionSe));
        when(generations.findAllByModelIdOrderByYearFromAsc(fusion.getId())).thenReturn(List.of(fusionGen));
        when(vpic.decode(FUSION_VIN, null)).thenReturn(fusion(2019, "SE", new BigDecimal("2.0"), "Gasoline", null, null));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).as("catalog SE is a 1.5, vPIC says 2.0").isEqualTo(MatchStatus.MODEL_ONLY);
        assertThat(r.match().variants()).isEmpty();
    }

    @Test
    void exact_trim_match_beats_token_overlap_among_hybrids() {
        VehicleVariant seHybrid = variant(fusionGen, 2019, "SE Hybrid", "2.0 Atkinson HEV", "sedan", FuelType.HYBRID);
        VehicleVariant selHybrid = variant(fusionGen, 2019, "SEL Hybrid", "2.0 Atkinson HEV", "sedan", FuelType.HYBRID);
        VehicleVariant titaniumHybrid = variant(fusionGen, 2019, "Titanium Hybrid", "2.0 Atkinson HEV", "sedan", FuelType.HYBRID);
        VehicleVariant titaniumEnergi = variant(fusionGen, 2019, "Titanium Energi", "2.0 Atkinson PHEV", "sedan", FuelType.HYBRID);
        when(makes.findByNameIgnoreCase("FORD")).thenReturn(Optional.of(ford));
        when(models.findAllByMakeIdAndNameIgnoreCase(ford.getId(), "Fusion")).thenReturn(List.of(fusion));
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(fusion.getId(), (short) 2019))
            .thenReturn(List.of(seHybrid, selHybrid, titaniumEnergi, titaniumHybrid, fusionSe, fusionTitanium));
        when(vpic.decode(FUSION_VIN, null)).thenReturn(
            fusion(2019, "SE Hybrid", new BigDecimal("2.0"), "Gasoline", "Electric", "Strong HEV (Hybrid Electric Vehicle)"));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).as("every hybrid shares the token 'hybrid'; the exact trim must win").isEqualTo(MatchStatus.EXACT);
        assertThat(r.match().variants()).extracting(VehicleVariantResponse::id).containsExactly(seHybrid.getId());
    }

    @Test
    void best_token_overlap_wins_when_no_trim_matches_exactly() {
        VehicleVariant seHybrid = variant(fusionGen, 2019, "SE Hybrid", "2.0 Atkinson HEV", "sedan", FuelType.HYBRID);
        VehicleVariant selHybrid = variant(fusionGen, 2019, "SEL Hybrid", "2.0 Atkinson HEV", "sedan", FuelType.HYBRID);
        VehicleVariant titaniumHybrid = variant(fusionGen, 2019, "Titanium Hybrid", "2.0 Atkinson HEV", "sedan", FuelType.HYBRID);
        when(makes.findByNameIgnoreCase("FORD")).thenReturn(Optional.of(ford));
        when(models.findAllByMakeIdAndNameIgnoreCase(ford.getId(), "Fusion")).thenReturn(List.of(fusion));
        when(variants.findAllByModelIdAndYearOrderByTrimAsc(fusion.getId(), (short) 2019))
            .thenReturn(List.of(seHybrid, selHybrid, titaniumHybrid));
        when(vpic.decode(FUSION_VIN, null)).thenReturn(
            fusion(2019, "SE Luxury Hybrid", new BigDecimal("2.0"), "Gasoline", "Electric", "Strong HEV (Hybrid Electric Vehicle)"));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.EXACT);
        assertThat(r.match().variants()).extracting(VehicleVariantResponse::id).containsExactly(seHybrid.getId());
    }

    @Test
    void model_only_when_the_catalog_has_no_variants_for_that_year() {
        catalogKnowsFord2019();
        when(vpic.decode(FUSION_VIN, null)).thenReturn(fusion(2015, "SE", null, "Gasoline", null, null));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.MODEL_ONLY);
        assertThat(r.match().variants()).isEmpty();
        assertThat(r.match().model().slug()).isEqualTo("fusion");
        assertThat(r.match().generation()).as("single generation whose range contains 2015").isNotNull();
    }

    @Test
    void make_only_when_the_model_is_unknown() {
        catalogKnowsFord2019();
        when(vpic.decode(FUSION_VIN, null)).thenReturn(
            decode("FORD", "Ranger", 2019, null, "XLT", "Pickup", null, "Gasoline", null, null));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.MAKE_ONLY);
        assertThat(r.match().make().slug()).isEqualTo("ford");
        assertThat(r.match().model()).isNull();
        assertThat(r.match().bodyType()).isEqualTo("pickup");
    }

    @Test
    void not_in_catalog_when_the_make_is_unknown() {
        when(vpic.decode(FUSION_VIN, null)).thenReturn(
            decode("TOYOTA", "Camry", 2019, null, "LE", "Sedan/Saloon", null, "Gasoline", null, null));

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.NOT_IN_CATALOG);
        assertThat(r.match().make()).isNull();
        assertThat(r.decoded().make()).isEqualTo("TOYOTA");
    }

    @Test
    void not_decoded_when_vpic_knows_nothing() {
        when(vpic.decode(FUSION_VIN, null)).thenReturn(nothing());

        VinLookupResponse r = service.lookup(FUSION_VIN, null);

        assertThat(r.status()).isEqualTo(MatchStatus.NOT_DECODED);
        assertThat(r.decoded().errorCode()).isEqualTo("8");
        verify(makes, never()).findByNameIgnoreCase(anyString());
    }

    @Test
    void rejects_malformed_input_before_calling_the_decoder() {
        assertThatThrownBy(() -> service.lookup("ABC", null)).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> service.lookup(FUSION_VIN, 1950)).isInstanceOf(BadRequestException.class);
        verify(vpic, never()).decode(anyString(), any());
    }

    @Test
    void normalises_the_vin_and_forwards_the_year_hint() {
        when(vpic.decode(FUSION_VIN, 2019)).thenReturn(nothing());

        VinLookupResponse r = service.lookup(" 3fa6p0lu4kr-123 456 ", 2019);

        assertThat(r.vin()).isEqualTo(FUSION_VIN);
        verify(vpic).decode(FUSION_VIN, 2019);
    }

    // --- fixtures -----------------------------------------------------------

    private static VpicDecodeResult fusion(
        int year, String trim, BigDecimal displacement, String fuelPrimary, String fuelSecondary, String electrification
    ) {
        return decode("FORD", "Fusion", year, null, trim, "Sedan/Saloon", displacement, fuelPrimary, fuelSecondary, electrification);
    }

    private static VpicDecodeResult decode(
        String make, String model, Integer year, String series, String trim, String bodyClass,
        BigDecimal displacement, String fuelPrimary, String fuelSecondary, String electrification
    ) {
        return new VpicDecodeResult(null, make, null, null, model, null, year, series, trim, bodyClass,
            "PASSENGER CAR", null, displacement, 4, null, null, fuelPrimary, fuelSecondary, electrification,
            "MEXICO", "0", null);
    }

    private static VpicDecodeResult nothing() {
        return new VpicDecodeResult(null, null, null, null, null, null, null, null, null, null, null, null,
            null, null, null, null, null, null, null, null, "8", "8 - No detailed data available currently");
    }

    private static VehicleMake make(String name, String slug) {
        return VehicleMake.builder().id(UUID.randomUUID()).name(name).slug(slug).popularity(0).build();
    }

    private static VehicleModel model(VehicleMake make, String name, String slug, int from, Integer to) {
        return VehicleModel.builder().id(UUID.randomUUID()).make(make).name(name).slug(slug)
            .yearFrom((short) from).yearTo(to == null ? null : to.shortValue()).build();
    }

    private static VehicleGeneration generation(
        VehicleModel model, String code, String name, String slug, int from, Integer to
    ) {
        return VehicleGeneration.builder().id(UUID.randomUUID()).model(model).code(code).name(name).slug(slug)
            .yearFrom((short) from).yearTo(to == null ? null : to.shortValue()).build();
    }

    private static VehicleVariant variant(
        VehicleGeneration gen, int year, String trim, String engineCode, String body, FuelType fuel
    ) {
        return VehicleVariant.builder().id(UUID.randomUUID()).generation(gen).year((short) year).trim(trim)
            .engineCode(engineCode).bodyType(body).fuel(fuel).build();
    }
}
