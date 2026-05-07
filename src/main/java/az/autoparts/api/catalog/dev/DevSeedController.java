package az.autoparts.api.catalog.dev;

import java.util.Map;

import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;

/**
 * Local-only catalog seeding endpoint. Wipes and reseeds the catalog tables
 * on each call. The whole controller is profile-gated so it never registers
 * outside local dev — prod will return 404 on this path.
 */
@RestController
@RequestMapping("/api/v1/dev/catalog")
@Profile("local")
@RequiredArgsConstructor
@Tag(name = "Dev — local only", description = "Endpoints available only with spring.profiles.active=local")
public class DevSeedController {

    private final DevSeedService devSeedService;

    @PostMapping("/seed")
    @Operation(summary = "Wipe catalog tables and reload demo data")
    public ResponseEntity<Map<String, Integer>> reseed() {
        return ResponseEntity.ok(devSeedService.reseed());
    }
}
