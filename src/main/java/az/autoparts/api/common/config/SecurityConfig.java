package az.autoparts.api.common.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import az.autoparts.api.common.security.JwtAuthenticationFilter;
import az.autoparts.api.common.security.JwtProperties;
import az.autoparts.api.common.security.RestAuthEntryPoint;
import az.autoparts.api.identity.service.AdminBootstrapProperties;

@Configuration
@EnableConfigurationProperties({JwtProperties.class, AdminBootstrapProperties.class})
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(
        HttpSecurity http,
        JwtAuthenticationFilter jwtFilter,
        RestAuthEntryPoint restAuthEntryPoint
    ) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            // Hand CORS handling to the CorsConfigurationSource bean. This
            // makes Spring Security emit Access-Control-* headers on its own
            // error responses (401 expired-JWT, 403 missing-role), so the
            // browser can read them and the axios 401 interceptor can fire
            // its login-redirect instead of surfacing as a "CORS blocked"
            // error in the console.
            .cors(Customizer.withDefaults())
            // Return 401 (not 403) for any anonymous hit on a protected path.
            // 403 stays for "authenticated but missing the required role".
            // The frontend interceptor's 401 → /login redirect depends on this
            // distinction.
            .exceptionHandling(eh -> eh.authenticationEntryPoint(restAuthEntryPoint))
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
}
