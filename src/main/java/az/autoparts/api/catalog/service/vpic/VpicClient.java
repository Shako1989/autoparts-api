package az.autoparts.api.catalog.service.vpic;

/** Decodes VINs through NHTSA's vPIC service. Implementations cache results. */
public interface VpicClient {

    /**
     * @param vin       17 characters, already normalised (upper case); '*' may stand
     *                  for an unknown position
     * @param modelYear optional hint that resolves the 30-year cycle of VIN position 10
     * @throws az.autoparts.api.common.error.UpstreamUnavailableException if vPIC
     *         cannot be reached or answers with an error status
     */
    VpicDecodeResult decode(String vin, Integer modelYear);
}
