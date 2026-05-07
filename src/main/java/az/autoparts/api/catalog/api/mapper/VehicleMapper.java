package az.autoparts.api.catalog.api.mapper;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import az.autoparts.api.catalog.api.dto.VehicleMakeResponse;
import az.autoparts.api.catalog.api.dto.VehicleModelResponse;
import az.autoparts.api.catalog.api.dto.VehicleVariantResponse;
import az.autoparts.api.catalog.domain.VehicleMake;
import az.autoparts.api.catalog.domain.VehicleModel;
import az.autoparts.api.catalog.domain.VehicleVariant;

@Mapper(componentModel = "spring")
public interface VehicleMapper {

    VehicleMakeResponse toMakeResponse(VehicleMake make);

    @Mapping(target = "makeId", source = "make.id")
    VehicleModelResponse toModelResponse(VehicleModel model);

    @Mapping(target = "modelId", source = "model.id")
    VehicleVariantResponse toVariantResponse(VehicleVariant variant);
}
