package az.autoparts.api.catalog.service.vpic;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import az.autoparts.api.common.error.UpstreamUnavailableException;

/**
 * Calls vPIC's flat decode endpoint ({@code DecodeVinValues}) and trims the
 * 145-field answer down to {@link VpicDecodeResult}. Cached per VIN + year hint.
 */
@Component
class VpicRestClient implements VpicClient {

    static final String CACHE = "vpic-decode";

    private static final Logger log = LoggerFactory.getLogger(VpicRestClient.class);

    private final RestClient http;

    VpicRestClient(@Qualifier(VpicConfig.HTTP_CLIENT) RestClient http) {
        this.http = http;
    }

    @Override
    @Cacheable(cacheNames = CACHE, key = "#vin + ':' + (#modelYear == null ? '' : #modelYear)")
    public VpicDecodeResult decode(String vin, Integer modelYear) {
        VpicResponse response;
        try {
            response = http.get()
                .uri(b -> {
                    b.path("/vehicles/DecodeVinValues/{vin}").queryParam("format", "json");
                    if (modelYear != null) {
                        b.queryParam("modelyear", modelYear);
                    }
                    return b.build(vin);
                })
                .retrieve()
                .body(VpicResponse.class);
        } catch (RestClientException e) {
            throw new UpstreamUnavailableException("VIN decoder (NHTSA vPIC) is unavailable", e);
        }

        Map<String, String> r = response == null || response.results() == null || response.results().isEmpty()
            ? Map.of()
            : response.results().get(0);

        VpicDecodeResult result = new VpicDecodeResult(
            text(r, "VehicleDescriptor"),
            text(r, "Make"),
            integer(r, "MakeID"),
            text(r, "Manufacturer"),
            text(r, "Model"),
            integer(r, "ModelID"),
            integer(r, "ModelYear"),
            text(r, "Series"),
            text(r, "Trim"),
            text(r, "BodyClass"),
            text(r, "VehicleType"),
            text(r, "DriveType"),
            decimal(r, "DisplacementL"),
            integer(r, "EngineCylinders"),
            integer(r, "EngineHP"),
            text(r, "EngineModel"),
            text(r, "FuelTypePrimary"),
            text(r, "FuelTypeSecondary"),
            text(r, "ElectrificationLevel"),
            text(r, "PlantCountry"),
            text(r, "ErrorCode"),
            text(r, "ErrorText")
        );
        log.debug("vPIC decode {} -> make={} model={} year={} trim={} error={}",
            vin, result.make(), result.model(), result.modelYear(), result.trim(), result.errorCode());
        return result;
    }

    private static String text(Map<String, String> r, String key) {
        String v = r.get(key);
        if (v == null) return null;
        v = v.trim();
        return v.isEmpty() || v.equalsIgnoreCase("Not Applicable") ? null : v;
    }

    private static Integer integer(Map<String, String> r, String key) {
        BigDecimal d = decimal(r, key);
        return d == null ? null : d.intValue();
    }

    private static BigDecimal decimal(Map<String, String> r, String key) {
        String v = text(r, key);
        if (v == null) return null;
        try {
            return new BigDecimal(v);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** vPIC's flat-format envelope. Only the first result is ever populated for a single VIN. */
    @JsonIgnoreProperties(ignoreUnknown = true)
    record VpicResponse(@JsonProperty("Results") List<Map<String, String>> results) {}
}
