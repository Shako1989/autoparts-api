package az.autoparts.api.catalog.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.Normalizer;
import java.time.Year;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import az.autoparts.api.catalog.domain.FuelType;
import az.autoparts.api.catalog.service.vpic.VpicDecodeResult;
import az.autoparts.api.common.error.BadRequestException;

/** Pure helpers for VIN validation and for translating vPIC vocabulary into catalog vocabulary. */
final class VinLookupSupport {

    private VinLookupSupport() {}

    /**
     * 17 characters without I, O, Q. '*' is accepted only where it loses nothing:
     * the check digit (position 9) and the serial number (positions 12–17).
     */
    private static final Pattern VIN = Pattern.compile(
        "[A-HJ-NPR-Z0-9]{8}[A-HJ-NPR-Z0-9*][A-HJ-NPR-Z0-9]{2}[A-HJ-NPR-Z0-9*]{6}");

    private static final int FIRST_17_CHAR_VIN_YEAR = 1981;

    /** "2.0" inside "2.0 EcoBoost" or "2.0T", but not the "20" in "N20B20" or a version like "1.0.3". */
    private static final Pattern LITRES = Pattern.compile("(?<![0-9.])[1-9]\\.[0-9](?![0-9.])");

    /** BMW-style model designations: 316d, 328i, 335is, 740Li. */
    private static final Pattern DESIGNATION = Pattern.compile("[0-9]{3}[a-z]{1,3}");

    static String normalizeVin(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new BadRequestException("VIN is required");
        }
        String vin = raw.replaceAll("[\\s-]", "").toUpperCase(Locale.ROOT);
        if (!VIN.matcher(vin).matches()) {
            throw new BadRequestException(
                "VIN must be 17 characters (digits and letters except I, O, Q); "
                    + "'*' is allowed only for the check digit and the serial number (positions 9 and 12-17)");
        }
        return vin;
    }

    static Integer validateYear(Integer year) {
        if (year == null) return null;
        int max = Year.now().getValue() + 1;
        if (year < FIRST_17_CHAR_VIN_YEAR || year > max) {
            throw new BadRequestException("year must be between " + FIRST_17_CHAR_VIN_YEAR + " and " + max);
        }
        return year;
    }

    /**
     * vPIC reports fuel as free text plus an electrification level; the catalog
     * has a 5-value enum. Order matters: electrification first, then fuel.
     */
    static FuelType inferFuel(VpicDecodeResult d) {
        String el = lower(d.electrificationLevel());
        String primary = lower(d.fuelPrimary());
        String secondary = lower(d.fuelSecondary());
        if (el.contains("bev") || el.contains("fcev") || (primary.contains("electric") && secondary.isEmpty())) {
            return FuelType.EV;
        }
        // Mild (48 V) hybrids share their parts with the combustion variant and
        // follow the primary fuel; strong hybrids and plug-ins are HYBRID.
        boolean mild = el.contains("mild");
        if (!mild && (el.contains("hev") || el.contains("hybrid")
            || secondary.contains("electric") || primary.contains("electric"))) {
            return FuelType.HYBRID;
        }
        if (primary.contains("diesel")) return FuelType.DIESEL;
        if (primary.contains("lpg") || primary.contains("propane") || primary.contains("cng")
            || primary.contains("natural gas")) {
            return FuelType.LPG;
        }
        if (primary.contains("gasoline") || primary.contains("petrol") || primary.contains("ethanol")
            || primary.contains("flex") || primary.contains("e85")) {
            return FuelType.PETROL;
        }
        return null;
    }

    /** Maps vPIC's BodyClass onto the body_type strings used in vehicle_variants. */
    static String inferBodyType(String bodyClass) {
        String b = lower(bodyClass);
        if (b.isEmpty()) return null;
        if (b.contains("sedan") || b.contains("saloon")) return "sedan";
        if (b.contains("hatchback") || b.contains("liftback")) return "hatchback";
        if (b.contains("wagon")) return "wagon";
        if (b.contains("convertible") || b.contains("cabriolet") || b.contains("roadster")) return "convertible";
        if (b.contains("coupe")) return "coupe";
        if (b.contains("sport utility") || b.contains("suv") || b.contains("crossover") || b.contains("cuv")
            || b.contains("multipurpose")) {
            return "SUV";
        }
        if (b.contains("pickup")) return "pickup";
        if (b.contains("minivan") || b.contains("van")) return "van";
        return null;
    }

    static String slugify(String value) {
        return Normalizer.normalize(value, Normalizer.Form.NFKD)
            .replaceAll("[^\\p{ASCII}]", "")
            .toLowerCase(Locale.ROOT)
            .replaceAll("[^a-z0-9]+", "-")
            .replaceAll("(^-+|-+$)", "");
    }

    /** Lower-cased alphanumeric tokens of at least two characters ("SE Hybrid" → {se, hybrid}). */
    static Set<String> tokens(String... values) {
        Set<String> out = new HashSet<>();
        for (String v : values) {
            if (v == null) continue;
            for (String t : v.toLowerCase(Locale.ROOT).split("[^a-z0-9.]+")) {
                if (t.length() >= 2) out.add(t);
            }
        }
        return out;
    }

    /** vPIC's displacement as the "2.0"-style figure people write in trims and engine names. */
    static String litres(BigDecimal displacement) {
        return displacement.setScale(1, RoundingMode.HALF_UP).toPlainString();
    }

    /** Every "2.0"-style litre figure mentioned in the given texts. */
    static Set<String> litresIn(String... texts) {
        Set<String> out = new HashSet<>();
        for (String text : texts) {
            if (text == null) continue;
            Matcher m = LITRES.matcher(text);
            while (m.find()) out.add(m.group());
        }
        return out;
    }

    /**
     * A BMW-style designation ("328i", "740 Li") normalised to lower case without
     * spaces, or null if the text is not one. vPIC reports such cars with the
     * designation as the model name, and the catalog files it as the trim; when
     * both sides are designations they must be equal.
     */
    static String designation(String text) {
        if (text == null) return null;
        String normalised = text.toLowerCase(Locale.ROOT).replaceAll("[\\s-]", "");
        return DESIGNATION.matcher(normalised).matches() ? normalised : null;
    }

    private static String lower(String s) {
        return s == null ? "" : s.toLowerCase(Locale.ROOT);
    }
}
