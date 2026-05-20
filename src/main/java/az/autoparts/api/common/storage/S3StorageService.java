package az.autoparts.api.common.storage;

import java.net.URL;
import java.time.Duration;

import org.springframework.stereotype.Service;

import lombok.RequiredArgsConstructor;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

@Service
@RequiredArgsConstructor
public class S3StorageService {

    private final S3Client s3;
    private final S3Presigner presigner;
    private final S3Properties props;

    public PresignedPut presignPut(String bucket, String key, String contentType, Duration ttl) {
        PutObjectRequest put = PutObjectRequest.builder()
            .bucket(bucket)
            .key(key)
            .contentType(contentType)
            .build();
        PutObjectPresignRequest preq = PutObjectPresignRequest.builder()
            .signatureDuration(ttl)
            .putObjectRequest(put)
            .build();
        URL url = presigner.presignPutObject(preq).url();
        return new PresignedPut(url.toString(), ttl.toSeconds());
    }

    public void deleteObject(String bucket, String key) {
        s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
    }

    public String listingsBucket() {
        return props.listingsBucket();
    }

    public String publicUrlForListing(String key) {
        return props.listingsPublicBase() + "/" + key;
    }

    public record PresignedPut(String uploadUrl, long expiresInSeconds) {}
}
