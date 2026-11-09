package az.autoparts.api.catalog.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * One fitment rule: a model year, optionally narrowed to a generation, trim
 * and/or engine. Null or blank narrowing fields mean "every variant"; set ones
 * match the variant's value case-insensitively. A rule that matches no variant
 * is rejected rather than silently adding nothing.
 */
public record FitmentInput(
    @NotBlank String makeSlug,
    @NotBlank String modelSlug,
    @NotNull @Positive Short year,
    String generationSlug,
    String trim,
    String engineCode
) {
    /** Legacy shape: the whole model year. */
    public FitmentInput(String makeSlug, String modelSlug, Short year) {
        this(makeSlug, modelSlug, year, null, null, null);
    }

    public boolean matches(az.autoparts.api.catalog.domain.VehicleVariant v) {
        return matchesText(generationSlug, v.getGeneration().getSlug())
            && matchesText(trim, v.getTrim())
            && matchesText(engineCode, v.getEngineCode());
    }

    private static boolean matchesText(String wanted, String actual) {
        if (wanted == null || wanted.isBlank()) return true;
        return actual != null && actual.trim().equalsIgnoreCase(wanted.trim());
    }

    /** "ford fusion 2017 [gen=cd391] [trim=SE] [engine=2.0 EcoBoost]" for error messages. */
    public String describe() {
        StringBuilder sb = new StringBuilder(makeSlug).append(' ').append(modelSlug).append(' ').append(year);
        if (generationSlug != null && !generationSlug.isBlank()) sb.append(" generation=").append(generationSlug.trim());
        if (trim != null && !trim.isBlank()) sb.append(" trim=").append(trim.trim());
        if (engineCode != null && !engineCode.isBlank()) sb.append(" engine=").append(engineCode.trim());
        return sb.toString();
    }
}
