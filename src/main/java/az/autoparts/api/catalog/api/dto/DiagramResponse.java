package az.autoparts.api.catalog.api.dto;

import java.util.List;
import java.util.UUID;

import az.autoparts.api.catalog.api.dto.PartResponse.PartNumberEntry;

public record DiagramResponse(
    UUID id,
    String slug,
    String title,
    String imageUrl,
    int imageWidth,
    int imageHeight,
    UUID categoryId,
    UUID vehicleVariantId,
    List<CalloutEntry> callouts
) {
    public record CalloutEntry(
        UUID id,
        String label,
        int x,
        int y,
        Integer w,
        Integer h,
        int zOrder,
        String notes,
        CalloutPart part
    ) {}

    public record CalloutPart(
        UUID id,
        String categorySlug,
        String name,
        String brand,
        String defaultImageUrl,
        List<PartNumberEntry> partNumbers
    ) {}
}
