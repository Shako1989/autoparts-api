package az.autoparts.api.catalog.api.dto;

import java.math.BigDecimal;
import java.util.List;

import az.autoparts.api.catalog.domain.FuelType;

/**
 * Result of decoding a VIN through NHTSA vPIC and matching it against the
 * catalog. {@code decoded} is what vPIC knows about the car; {@code match} is
 * what could be mapped onto our own make → model → generation → variant rows.
 */
public record VinLookupResponse(
    String vin,
    MatchStatus status,
    DecodedVehicle decoded,
    CatalogMatch match
) {

    public enum MatchStatus {
        /** Exactly one catalog variant matches. */
        EXACT,
        /** Several variants of the right model and year remain; the user must pick one. */
        AMBIGUOUS,
        /** Model found, but the catalog has no variants for that model year. */
        MODEL_ONLY,
        /** Make found, but the model is not in the catalog. */
        MAKE_ONLY,
        /** vPIC decoded the VIN, but the make is not in the catalog. */
        NOT_IN_CATALOG,
        /** vPIC could not decode the VIN (typically a vehicle never sold in the US). */
        NOT_DECODED
    }

    public record DecodedVehicle(
        String make,
        String model,
        Integer year,
        String series,
        String trim,
        String bodyClass,
        String vehicleType,
        String driveType,
        Engine engine,
        String plantCountry,
        String errorCode,
        String errorText
    ) {}

    public record Engine(
        BigDecimal displacementL,
        Integer cylinders,
        Integer horsepower,
        String engineModel,
        String fuelPrimary,
        String fuelSecondary,
        String electrificationLevel
    ) {}

    /**
     * @param fuel     catalog fuel inferred from vPIC's fuel and electrification fields; null if unknown
     * @param bodyType catalog body type inferred from vPIC's body class; null if unknown
     */
    public record CatalogMatch(
        VehicleMakeResponse make,
        VehicleModelResponse model,
        VehicleGenerationResponse generation,
        List<VehicleVariantResponse> variants,
        FuelType fuel,
        String bodyType
    ) {
        public static CatalogMatch none(FuelType fuel, String bodyType) {
            return new CatalogMatch(null, null, null, List.of(), fuel, bodyType);
        }
    }
}
