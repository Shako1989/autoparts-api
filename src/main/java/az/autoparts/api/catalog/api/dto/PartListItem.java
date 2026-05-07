package az.autoparts.api.catalog.api.dto;

import java.util.UUID;

/**
 * Lightweight representation of a Part for list/grid pages.
 * Omits part numbers (loaded only on the detail page) to keep list queries cheap.
 */
public record PartListItem(
    UUID id,
    String name,
    String brand,
    String defaultImageUrl
) {}
