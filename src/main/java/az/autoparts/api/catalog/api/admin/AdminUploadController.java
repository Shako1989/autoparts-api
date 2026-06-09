package az.autoparts.api.catalog.api.admin;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.catalog.api.admin.dto.AdminPresignedUploadResponse;
import az.autoparts.api.catalog.api.admin.dto.PresignImageUploadRequest;
import az.autoparts.api.catalog.service.CatalogAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/admin/uploads")
@PreAuthorize("hasAnyRole('STAFF','ADMIN')")
@RequiredArgsConstructor
public class AdminUploadController {

    private final CatalogAdminService admin;

    @PostMapping("/catalog-image/presign")
    public AdminPresignedUploadResponse presignCatalogImage(
        @Valid @RequestBody PresignImageUploadRequest request
    ) {
        return admin.presignCatalogImageUpload(request.contentType());
    }
}
