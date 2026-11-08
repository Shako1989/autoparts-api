package az.autoparts.api.catalog.service.vpic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import az.autoparts.api.common.error.UpstreamUnavailableException;

class VpicRestClientTest {

    /** Trimmed copy of a real vPIC answer for a 2019 Ford Fusion SE Hybrid with a masked serial. */
    private static final String FUSION_JSON = """
        {"Count":145,"Message":"Results returned successfully","SearchCriteria":"VIN(s): 3FA6P0LU4KR******",
         "Results":[{"Make":"FORD","MakeID":"460","Manufacturer":"FORD MOTOR COMPANY, MEXICO","Model":"Fusion",
           "ModelID":"1780","ModelYear":"2019","Series":"","Trim":"SE Hybrid","BodyClass":"Sedan/Saloon",
           "VehicleType":"PASSENGER CAR","DriveType":"","DisplacementL":"2.0","EngineCylinders":"4","EngineHP":"188",
           "EngineModel":"","FuelTypePrimary":"Gasoline","FuelTypeSecondary":"Electric",
           "ElectrificationLevel":"Strong HEV (Hybrid Electric Vehicle)","PlantCountry":"MEXICO",
           "BusType":"Not Applicable","ErrorCode":"1",
           "ErrorText":"1 - Check Digit (9th position) does not calculate properly",
           "VehicleDescriptor":"3FA6P0LU*KR","VIN":"3FA6P0LU4KR******"}]}
        """;

    private MockRestServiceServer server;
    private VpicRestClient client;

    @BeforeEach
    void setUp() {
        RestClient.Builder builder = RestClient.builder().baseUrl("https://vpic.test/api");
        server = MockRestServiceServer.bindTo(builder).build();
        client = new VpicRestClient(builder.build());
    }

    @Test
    void decodes_flat_payload_and_normalises_blanks_to_null() {
        server.expect(requestTo(
                "https://vpic.test/api/vehicles/DecodeVinValues/3FA6P0LU4KR%2A%2A%2A%2A%2A%2A?format=json&modelyear=2019"))
            .andExpect(method(HttpMethod.GET))
            .andRespond(withSuccess(FUSION_JSON, MediaType.APPLICATION_JSON));

        VpicDecodeResult r = client.decode("3FA6P0LU4KR******", 2019);

        assertThat(r.vehicleDescriptor()).isEqualTo("3FA6P0LU*KR");
        assertThat(r.make()).isEqualTo("FORD");
        assertThat(r.makeId()).isEqualTo(460);
        assertThat(r.model()).isEqualTo("Fusion");
        assertThat(r.modelYear()).isEqualTo(2019);
        assertThat(r.trim()).isEqualTo("SE Hybrid");
        assertThat(r.bodyClass()).isEqualTo("Sedan/Saloon");
        assertThat(r.displacementL()).isEqualByComparingTo("2.0");
        assertThat(r.cylinders()).isEqualTo(4);
        assertThat(r.horsepower()).isEqualTo(188);
        assertThat(r.fuelPrimary()).isEqualTo("Gasoline");
        assertThat(r.fuelSecondary()).isEqualTo("Electric");
        assertThat(r.electrificationLevel()).startsWith("Strong HEV");
        assertThat(r.plantCountry()).isEqualTo("MEXICO");
        assertThat(r.errorCode()).isEqualTo("1");
        assertThat(r.series()).as("empty string becomes null").isNull();
        assertThat(r.driveType()).isNull();
        assertThat(r.engineModel()).isNull();
        server.verify();
    }

    @Test
    void omits_the_year_parameter_when_no_hint_is_given_and_handles_empty_results() {
        server.expect(requestTo("https://vpic.test/api/vehicles/DecodeVinValues/WBA3A5C50DF123456?format=json"))
            .andRespond(withSuccess("{\"Count\":0,\"Message\":\"ok\",\"Results\":[]}", MediaType.APPLICATION_JSON));

        VpicDecodeResult r = client.decode("WBA3A5C50DF123456", null);

        assertThat(r.make()).isNull();
        assertThat(r.modelYear()).isNull();
        server.verify();
    }

    @Test
    void server_error_becomes_upstream_unavailable() {
        server.expect(requestTo(startsWith("https://vpic.test/api/vehicles/DecodeVinValues/")))
            .andRespond(withServerError());

        assertThatThrownBy(() -> client.decode("3FA6P0LU4KR123456", null))
            .isInstanceOf(UpstreamUnavailableException.class)
            .hasMessageContaining("vPIC");
    }
}
