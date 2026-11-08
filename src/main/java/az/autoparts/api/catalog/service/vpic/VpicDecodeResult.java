package az.autoparts.api.catalog.service.vpic;

import java.math.BigDecimal;

/**
 * The subset of NHTSA vPIC's ~145 decode variables that the catalog cares about.
 * Every field is nullable: vPIC returns empty strings for anything it does not
 * know and the client normalises those to null. {@code make == null} means the
 * VIN could not be decoded at all (typical for vehicles never sold in the US).
 */
public record VpicDecodeResult(
    String vehicleDescriptor,
    String make,
    Integer makeId,
    String manufacturer,
    String model,
    Integer modelId,
    Integer modelYear,
    String series,
    String trim,
    String bodyClass,
    String vehicleType,
    String driveType,
    BigDecimal displacementL,
    Integer cylinders,
    Integer horsepower,
    String engineModel,
    String fuelPrimary,
    String fuelSecondary,
    String electrificationLevel,
    String plantCountry,
    String errorCode,
    String errorText
) {}
