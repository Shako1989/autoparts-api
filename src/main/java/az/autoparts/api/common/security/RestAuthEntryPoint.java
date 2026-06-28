package az.autoparts.api.common.security;

import java.io.IOException;
import java.net.URI;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;

/**
 * Returns 401 (not 403) when a protected endpoint is hit without authentication
 * — missing Authorization header, expired JWT, malformed JWT, anything that
 * leaves the SecurityContext empty. 403 stays reserved for "authenticated but
 * lacking the required role" (handled by Spring's default AccessDeniedHandler).
 *
 * This is the semantic the frontend axios interceptor expects: on 401 it clears
 * the auth store and redirects to /login. Without this entry point Spring would
 * return 403 for all auth failures and the redirect would never fire — the user
 * would just see "Failed to load…" until they manually re-logged in.
 */
@Component
@RequiredArgsConstructor
public class RestAuthEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper json;

    @Override
    public void commence(
        HttpServletRequest request,
        HttpServletResponse response,
        AuthenticationException authException
    ) throws IOException {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, "Authentication required");
        pd.setType(URI.create("https://autoparts.az/problems/unauthorized"));
        pd.setTitle("Unauthorized");

        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        json.writeValue(response.getOutputStream(), pd);
    }
}
