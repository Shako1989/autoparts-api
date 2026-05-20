package az.autoparts.api.identity.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.common.security.CurrentUser;
import az.autoparts.api.identity.api.dto.BecomeSellerRequest;
import az.autoparts.api.identity.api.dto.SellerProfileResponse;
import az.autoparts.api.identity.api.dto.UpdateSellerProfileRequest;
import az.autoparts.api.identity.service.SellerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/my/seller")
@RequiredArgsConstructor
public class SellerController {

    private final SellerService sellerService;

    @PostMapping
    public SellerProfileResponse becomeSeller(@Valid @RequestBody BecomeSellerRequest request) {
        return sellerService.becomeSeller(CurrentUser.requireId(), request);
    }

    @GetMapping
    public SellerProfileResponse getMyProfile() {
        return sellerService.getMyProfile(CurrentUser.requireId());
    }

    @PatchMapping
    public SellerProfileResponse updateMyProfile(@Valid @RequestBody UpdateSellerProfileRequest request) {
        return sellerService.updateMyProfile(CurrentUser.requireId(), request);
    }
}
