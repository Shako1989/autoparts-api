package az.autoparts.api.listings.api.dto;

public record PresignedUploadResponse(
    String uploadUrl,
    String s3Key,
    String publicUrl,
    long expiresInSeconds
) {}
