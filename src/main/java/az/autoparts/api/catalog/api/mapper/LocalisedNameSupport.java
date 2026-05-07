package az.autoparts.api.catalog.api.mapper;

import az.autoparts.api.catalog.domain.Category;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.common.locale.Locale;

/**
 * Picks the localised name from an entity based on the active {@link Locale}.
 * Used by MapStruct mappers via {@code @Mapping(... qualifiedByName)} or directly from helpers.
 */
public final class LocalisedNameSupport {

    private LocalisedNameSupport() {}

    public static String name(Category c, Locale locale) {
        if (c == null) return null;
        return switch (locale) {
            case RU -> c.getNameRu();
            case EN -> c.getNameEn();
            case AZ -> c.getNameAz();
        };
    }

    public static String name(Part p, Locale locale) {
        if (p == null) return null;
        return switch (locale) {
            case RU -> p.getNameRu();
            case EN -> p.getNameEn();
            case AZ -> p.getNameAz();
        };
    }
}
