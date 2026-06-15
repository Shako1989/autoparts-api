package az.autoparts.api.common.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.s3")
public record S3Properties(
    String endpoint,
    // Optional: external URL the presigner should bake into upload URLs.
    // If null, falls back to `endpoint`. In production this should point
    // at the public CDN host that proxies through to MinIO (e.g.
    // https://cdn.bakuparts.com), so browsers can use the presigned PUT.
    String publicEndpoint,
    String region,
    String accessKey,
    String secretKey,
    String bucket,
    String listingsBucket,
    String listingsPublicBase,
    String catalogBucket,
    String catalogPublicBase
) {}
