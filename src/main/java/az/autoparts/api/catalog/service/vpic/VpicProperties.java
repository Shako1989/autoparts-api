package az.autoparts.api.catalog.service.vpic;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Settings for the NHTSA vPIC VIN decoder client, bound from {@code app.vpic.*}.
 * vPIC is free and public domain but rate-controlled, hence the long cache TTL.
 */
@ConfigurationProperties(prefix = "app.vpic")
public record VpicProperties(
    @DefaultValue("https://vpic.nhtsa.dot.gov/api") String baseUrl,
    @DefaultValue("3s") Duration connectTimeout,
    @DefaultValue("10s") Duration readTimeout,
    @DefaultValue("30d") Duration cacheTtl
) {}
