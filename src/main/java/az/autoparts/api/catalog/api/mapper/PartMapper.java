package az.autoparts.api.catalog.api.mapper;

import java.util.List;

import az.autoparts.api.catalog.api.dto.FitmentResponse;
import az.autoparts.api.catalog.api.dto.PartResponse;
import az.autoparts.api.catalog.api.dto.PartResponse.PartNumberEntry;
import az.autoparts.api.catalog.domain.Fitment;
import az.autoparts.api.catalog.domain.Part;
import az.autoparts.api.catalog.domain.PartNumber;
import az.autoparts.api.catalog.domain.VehicleVariant;
import az.autoparts.api.common.locale.Locale;

import org.springframework.stereotype.Component;

@Component
public class PartMapper {

    public PartResponse toResponse(Part part, List<PartNumber> numbers, Locale locale) {
        List<PartNumberEntry> numberEntries = numbers.stream()
            .map(n -> new PartNumberEntry(n.getNumber(), n.getType(), n.getSource()))
            .toList();

        return new PartResponse(
            part.getId(),
            part.getCategory().getId(),
            part.getCategory().getSlug(),
            LocalisedNameSupport.name(part, locale),
            part.getBrand(),
            part.getDescription(),
            part.getDefaultImageUrl(),
            numberEntries
        );
    }

    public FitmentResponse toFitmentResponse(Fitment fitment) {
        VehicleVariant variant = fitment.getVehicleVariant();
        return new FitmentResponse(
            fitment.getId(),
            fitment.getPart().getId(),
            variant.getId(),
            variant.getModel().getMake().getName(),
            variant.getModel().getName(),
            variant.getYear(),
            variant.getTrim(),
            variant.getEngineCode(),
            fitment.getPosition(),
            fitment.getNotes()
        );
    }
}
