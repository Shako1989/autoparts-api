package az.autoparts.api.common.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.access.hierarchicalroles.RoleHierarchy;
import org.springframework.security.access.hierarchicalroles.RoleHierarchyImpl;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import az.autoparts.api.common.security.JwtAuthenticationFilter;
import az.autoparts.api.common.security.JwtProperties;
import az.autoparts.api.identity.service.AdminBootstrapProperties;

@Configuration
@EnableConfigurationProperties({JwtProperties.class, AdminBootstrapProperties.class})
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, JwtAuthenticationFilter jwtFilter) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // CORS preflight: let the CorsFilter answer OPTIONS on any path
                // before Spring Security rejects anonymous requests on protected paths.
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/api/v1/catalog/**").permitAll()
                .requestMatchers("/api/v1/search").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/listings/*").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/parts/**").permitAll()
                .requestMatchers("/api/v1/dev/**").permitAll()
                .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * Role hierarchy: a higher-privilege role implicitly satisfies all lower-privilege
     * checks. So a STAFF user can use any endpoint marked @PreAuthorize("hasRole('SELLER')"),
     * which is the right model for the platform's own admins (they need to be able to
     * exercise the seller flow, e.g. for support / debugging / dogfooding).
     *
     * Spring Security 6 picks this bean up automatically for both URL-level and
     * method-level (@PreAuthorize) authorization.
     */
    @Bean
    RoleHierarchy roleHierarchy() {
        return RoleHierarchyImpl.fromHierarchy("""
            ROLE_ADMIN > ROLE_STAFF
            ROLE_STAFF > ROLE_SELLER
            ROLE_SELLER > ROLE_BUYER
            """);
    }
}
