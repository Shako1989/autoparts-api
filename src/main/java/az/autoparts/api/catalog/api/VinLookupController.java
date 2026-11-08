package az.autoparts.api.catalog.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import az.autoparts.api.catalog.api.dto.VinLookupResponse;
import az.autoparts.api.catalog.service.VinLookupService;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1/catalog/vin")
@RequiredArgsConstructor
public class VinLookupController {

    private final VinLookupService vinLookupService;

    /**
     * Decodes a VIN through NHTSA vPIC and maps it onto catalog make / model /
     * generation / variants. A well-formed VIN always yields 200; {@code status}
     * says how far the match got. 400 for a malformed VIN, 503 if vPIC is down.
     */
    @GetMapping("/{vin}")
    public VinLookupResponse lookup(
        @PathVariable String vin,
        @RequestParam(name = "year", required = false) Integer year
    ) {
        return vinLookupService.lookup(vin, year);
    }
}
