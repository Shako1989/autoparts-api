package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

/**
 * Where a specific part appears as a callout on a diagram. Used in the admin
 * Part editor's Callouts tab to show every diagram that references this part.
 */
public record AdminPartCalloutLocation(
    UUID calloutId,
    UUID diagramId,
    String diagramSlug,
    String diagramTitleEn,
    String diagramImageUrl,
    int diagramImageWidth,
    int diagramImageHeight,
    String label,
    int x,
    int y
) {}
