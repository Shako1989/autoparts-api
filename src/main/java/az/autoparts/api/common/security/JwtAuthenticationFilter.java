package az.autoparts.api.common.security;

import java.io.IOException;
import java.util.List;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final CurrentRoleResolver roleResolver;

    @Override
    protected void doFilterInternal(
        HttpServletRequest request, HttpServletResponse response, FilterChain chain
    ) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                JwtService.ParsedToken parsed = jwtService.parse(token);
                Role role = roleResolver.resolveRole(parsed.userId()).orElse(parsed.role());
                var authority = new SimpleGrantedAuthority("ROLE_" + role.name());
                var auth = new UsernamePasswordAuthenticationToken(parsed.userId(), null, List.of(authority));
                auth.setDetails(parsed);
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (Exception e) {
                log.debug("Invalid JWT: {}", e.getMessage());
                SecurityContextHolder.clearContext();
            }
        }
        chain.doFilter(request, response);
    }
}
