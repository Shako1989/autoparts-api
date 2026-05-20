package az.autoparts.api.common.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.s3")
public record S3Properties(
    String endpoint,
    String region,
    String accessKey,
    String secretKey,
    String bucket,
    String listingsBucket,
    String listingsPublicBase
) {}
