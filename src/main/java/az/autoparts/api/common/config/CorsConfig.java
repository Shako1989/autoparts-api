package az.autoparts.api.common.config;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
public class CorsConfig {

    /**
     * Exposed as a {@link CorsConfigurationSource} so that Spring Security can
     * pick it up via {@code http.cors(Customizer.withDefaults())} and emit
     * Access-Control-* headers on its own error responses (401/403). The previous
     * setup registered a global {@code CorsFilter} bean, which works for normal
     * responses but is bypassed when Spring Security writes the response itself —
     * leaving expired-token 401s without CORS headers and surfacing as confusing
     * "CORS blocked" errors in the browser instead of a clean 401.
     */
    @Bean
    CorsConfigurationSource corsConfigurationSource(
        @Value("#{'${app.cors.allowed-origins}'.split(',')}") List<String> allowedOrigins
    ) {
        CorsConfiguration cfg = new CorsConfiguration();
        cfg.setAllowedOriginPatterns(allowedOrigins);
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cfg.setAllowedHeaders(List.of("*"));
        cfg.setExposedHeaders(List.of("Location", "Content-Disposition"));
        cfg.setAllowCredentials(true);
        cfg.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cfg);
        return source;
    }
}
