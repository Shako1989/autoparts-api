package az.autoparts.api.common.locale;

import java.util.List;

import org.springframework.web.servlet.LocaleResolver;
import org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Application locale enum. The brief calls for AZ (default), RU, EN.
 * The wire form is the lowercase ISO 639-1 code.
 */
public enum Locale {
    AZ, RU, EN;

    public static Locale fromHeaderOrDefault(String acceptLanguage) {
        if (acceptLanguage == null || acceptLanguage.isBlank()) return AZ;
        String lc = acceptLanguage.toLowerCase();
        if (lc.startsWith("ru")) return RU;
        if (lc.startsWith("en")) return EN;
        if (lc.startsWith("az")) return AZ;
        return AZ;
    }

    /**
     * Spring i18n config: resolve locale from Accept-Language with AZ default.
     * Kept here so the enum and resolver live together.
     */
    @Configuration
    static class WebLocaleConfig {
        @Bean
        LocaleResolver localeResolver() {
            AcceptHeaderLocaleResolver r = new AcceptHeaderLocaleResolver();
            r.setSupportedLocales(List.of(
                java.util.Locale.forLanguageTag("az"),
                java.util.Locale.forLanguageTag("ru"),
                java.util.Locale.forLanguageTag("en")
            ));
            r.setDefaultLocale(java.util.Locale.forLanguageTag("az"));
            return r;
        }
    }
}
