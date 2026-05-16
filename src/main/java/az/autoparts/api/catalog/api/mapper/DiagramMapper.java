package az.autoparts.api.catalog.api.mapper;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Component;

import az.autoparts.api.catalog.api.dto.DiagramResponse;
import az.autoparts.api.catalog.api.dto.DiagramResponse.CalloutEntry;
import az.autoparts.api.catalog.api.dto.DiagramResponse.CalloutPart;
import az.autoparts.api.catalog.api.dto.PartResponse.PartNumberEntry;
import az.autoparts.api.catalog.domain.Diagram;
import az.autoparts.api.catalog.domain.DiagramCallout;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.catalog.domain.PartNumber;
import az.autoparts.api.common.locale.Locale;

@Component
public class DiagramMapper {

    public DiagramResponse toResponse(
        Diagram diagram,
        List<DiagramCallout> callouts,
        Map<UUID, List<PartNumber>> numbersByPartId,
        Locale locale
    ) {
        return new DiagramResponse(
            diagram.getId(),
            diagram.getSlug(),
            localisedTitle(diagram, locale),
            diagram.getImageUrl(),
            diagram.getImageWidth(),
            diagram.getImageHeight(),
            diagram.getCategory() == null ? null : diagram.getCategory().getId(),
            diagram.getVehicleVariant() == null ? null : diagram.getVehicleVariant().getId(),
            callouts.stream()
                .map(c -> toCallout(c, numbersByPartId.getOrDefault(c.getPart().getId(), List.of()), locale))
                .toList()
        );
    }

    private CalloutEntry toCallout(DiagramCallout c, List<PartNumber> numbers, Locale locale) {
        Part part = c.getPart();
        List<PartNumberEntry> numberEntries = numbers.stream()
            .map(n -> new PartNumberEntry(n.getNumber(), n.getType(), n.getSource()))
            .toList();
        CalloutPart calloutPart = new CalloutPart(
            part.getId(),
            part.getCategory().getSlug(),
            LocalisedNameSupport.name(part, locale),
            part.getBrand(),
            part.getDefaultImageUrl(),
            numberEntries
        );
        return new CalloutEntry(
            c.getId(),
            c.getLabel(),
            c.getX(),
            c.getY(),
            c.getW(),
            c.getH(),
            c.getZOrder(),
            c.getNotes(),
            calloutPart
        );
    }

    private String localisedTitle(Diagram d, Locale locale) {
        return switch (locale) {
            case RU -> d.getTitleRu();
            case EN -> d.getTitleEn();
            case AZ -> d.getTitleAz();
        };
    }
}
