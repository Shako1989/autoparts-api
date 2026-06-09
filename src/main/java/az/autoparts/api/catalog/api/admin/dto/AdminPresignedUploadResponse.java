package az.autoparts.api.catalog.api.admin.dto;

public record AdminPresignedUploadResponse(
    String uploadUrl,
    String s3Key,
    String publicUrl,
    long expiresInSeconds
) {}
