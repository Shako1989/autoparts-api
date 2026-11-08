package az.autoparts.api.catalog.service;

import az.autoparts.api.catalog.api.dto.VinLookupResponse;

/**
 * Public API for VIN → catalog vehicle resolution. Decodes through NHTSA vPIC,
 * then maps the answer onto catalog make / model / generation / variants.
 */
public interface VinLookupService {

    /**
     * @param vin       17 characters; letters I, O and Q are never valid; '*' may
     *                  stand in for the check digit and the serial number
     * @param modelYear optional hint for the decoder (VIN position 10 repeats every 30 years)
     * @throws az.autoparts.api.common.error.BadRequestException          for a malformed VIN or year
     * @throws az.autoparts.api.common.error.UpstreamUnavailableException if the decoder is down
     */
    VinLookupResponse lookup(String vin, Integer modelYear);
}
