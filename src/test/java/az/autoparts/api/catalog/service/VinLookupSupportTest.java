package az.autoparts.api.catalog.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import az.autoparts.api.catalog.domain.FuelType;
import az.autoparts.api.catalog.service.vpic.VpicDecodeResult;
import az.autoparts.api.common.error.BadRequestException;

class VinLookupSupportTest {

    @Test
    void normalises_and_validates_vins() {
        assertThat(VinLookupSupport.normalizeVin(" 3fa6p0lu4kr-123 456 ")).isEqualTo("3FA6P0LU4KR123456");
        assertThat(VinLookupSupport.normalizeVin("3FA6P0LU*KR******")).isEqualTo("3FA6P0LU*KR******");

        assertThatThrownBy(() -> VinLookupSupport.normalizeVin("ABC")).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> VinLookupSupport.normalizeVin("3FA6P0LU4KR12345I"))
            .as("I is never a VIN character").isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> VinLookupSupport.normalizeVin("3FA6P0L*4KR123456"))
            .as("wildcards are not allowed inside the attribute section").isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> VinLookupSupport.normalizeVin(null)).isInstanceOf(BadRequestException.class);
    }

    @Test
    void validates_year_hint_range() {
        assertThat(VinLookupSupport.validateYear(null)).isNull();
        assertThat(VinLookupSupport.validateYear(2019)).isEqualTo(2019);
        assertThatThrownBy(() -> VinLookupSupport.validateYear(1950)).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> VinLookupSupport.validateYear(2999)).isInstanceOf(BadRequestException.class);
    }

    @Test
    void infers_catalog_fuel_from_vpic_fuel_and_electrification() {
        assertThat(VinLookupSupport.inferFuel(fuel("Gasoline", null, null))).isEqualTo(FuelType.PETROL);
        assertThat(VinLookupSupport.inferFuel(fuel("Flexible Fuel Vehicle (FFV)", null, null))).isEqualTo(FuelType.PETROL);
        assertThat(VinLookupSupport.inferFuel(fuel("Diesel", null, null))).isEqualTo(FuelType.DIESEL);
        assertThat(VinLookupSupport.inferFuel(fuel("Gasoline", "Electric", "Strong HEV (Hybrid Electric Vehicle)")))
            .isEqualTo(FuelType.HYBRID);
        assertThat(VinLookupSupport.inferFuel(fuel("Gasoline", null, "PHEV (Plug-in Hybrid Electric Vehicle)")))
            .isEqualTo(FuelType.HYBRID);
        assertThat(VinLookupSupport.inferFuel(fuel("Electric", null, "BEV (Battery Electric Vehicle)"))).isEqualTo(FuelType.EV);
        assertThat(VinLookupSupport.inferFuel(fuel("Gasoline", "Electric", "Mild HEV (Mild Hybrid Electric Vehicle)")))
            .as("48 V mild hybrids follow their combustion fuel").isEqualTo(FuelType.PETROL);
        assertThat(VinLookupSupport.inferFuel(fuel("Diesel", null, "Mild HEV (Mild Hybrid Electric Vehicle)")))
            .isEqualTo(FuelType.DIESEL);
        assertThat(VinLookupSupport.inferFuel(fuel("Compressed Natural Gas (CNG)", null, null))).isEqualTo(FuelType.LPG);
        assertThat(VinLookupSupport.inferFuel(fuel(null, null, null))).isNull();
    }

    @Test
    void infers_catalog_body_type_from_vpic_body_class() {
        assertThat(VinLookupSupport.inferBodyType("Sedan/Saloon")).isEqualTo("sedan");
        assertThat(VinLookupSupport.inferBodyType("Hatchback/Liftback/Notchback")).isEqualTo("hatchback");
        assertThat(VinLookupSupport.inferBodyType("Sport Utility Vehicle (SUV)/Multipurpose Passenger Vehicle (MPV)"))
            .isEqualTo("SUV");
        assertThat(VinLookupSupport.inferBodyType("Crossover Utility Vehicle (CUV)")).isEqualTo("SUV");
        assertThat(VinLookupSupport.inferBodyType("Convertible/Cabriolet")).isEqualTo("convertible");
        assertThat(VinLookupSupport.inferBodyType("Coupe")).isEqualTo("coupe");
        assertThat(VinLookupSupport.inferBodyType("Wagon")).isEqualTo("wagon");
        assertThat(VinLookupSupport.inferBodyType("Limousine")).isNull();
        assertThat(VinLookupSupport.inferBodyType(null)).isNull();
    }

    @Test
    void slugs_and_tokens() {
        assertThat(VinLookupSupport.slugify("MERCEDES-BENZ")).isEqualTo("mercedes-benz");
        assertThat(VinLookupSupport.slugify("3 Series")).isEqualTo("3-series");
        assertThat(VinLookupSupport.tokens("SE Hybrid")).containsExactlyInAnyOrder("se", "hybrid");
        assertThat(VinLookupSupport.tokens("xDrive35i", null, "3 Series")).containsExactlyInAnyOrder("xdrive35i", "series");
        assertThat(VinLookupSupport.tokens((String) null)).isEmpty();
    }

    @Test
    void litre_figures_and_designations() {
        assertThat(VinLookupSupport.litres(new BigDecimal("2.00"))).isEqualTo("2.0");
        assertThat(VinLookupSupport.litres(new BigDecimal("1.598"))).isEqualTo("1.6");
        assertThat(VinLookupSupport.litresIn("2.0 EcoBoost", "N20B20")).containsExactly("2.0");
        assertThat(VinLookupSupport.litresIn("1.5T SE", "2.0 Atkinson HEV")).containsExactlyInAnyOrder("1.5", "2.0");
        assertThat(VinLookupSupport.litresIn("N20B20", "v1.0.3", null)).isEmpty();

        assertThat(VinLookupSupport.designation("328i")).isEqualTo("328i");
        assertThat(VinLookupSupport.designation("740 Li")).isEqualTo("740li");
        assertThat(VinLookupSupport.designation("335is")).isEqualTo("335is");
        assertThat(VinLookupSupport.designation("SE Hybrid")).isNull();
        assertThat(VinLookupSupport.designation("Fusion")).isNull();
        assertThat(VinLookupSupport.designation(null)).isNull();
    }

    @Test
    void normalises_trims_for_exact_comparison() {
        assertThat(VinLookupSupport.normalizeTrim("SE  Hybrid")).isEqualTo("se hybrid");
        assertThat(VinLookupSupport.normalizeTrim("se-hybrid")).isEqualTo("se hybrid");
        assertThat(VinLookupSupport.normalizeTrim("  ")).isNull();
        assertThat(VinLookupSupport.normalizeTrim(null)).isNull();
    }

    private static VpicDecodeResult fuel(String primary, String secondary, String electrification) {
        return new VpicDecodeResult(null, "FORD", null, null, "Fusion", null, 2019, null, null, null, null, null,
            null, null, null, null, primary, secondary, electrification, null, "0", null);
    }
}
