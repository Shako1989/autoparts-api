package az.autoparts.api.common.security;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

import javax.crypto.SecretKey;

import org.springframework.stereotype.Service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

@Service
public class JwtService {

    private final JwtProperties props;
    private final SecretKey key;

    public JwtService(JwtProperties props) {
        this.props = props;
        if (props.secret() == null || props.secret().length() < 32) {
            throw new IllegalStateException(
                "app.jwt.secret must be set to at least 32 characters for HS256 signing");
        }
        this.key = Keys.hmacShaKeyFor(props.secret().getBytes(StandardCharsets.UTF_8));
    }

    public TokenPair issue(UUID userId, Role role, String phone) {
        Instant now = Instant.now();
        Instant exp = now.plus(props.accessTtl());
        String token = Jwts.builder()
            .issuer(props.issuer())
            .subject(userId.toString())
            .claim("role", role.name())
            .claim("phone", phone)
            .issuedAt(Date.from(now))
            .expiration(Date.from(exp))
            .signWith(key)
            .compact();
        return new TokenPair(token, exp, props.accessTtl().getSeconds());
    }

    public ParsedToken parse(String token) {
        Jws<Claims> jws = Jwts.parser()
            .verifyWith(key)
            .build()
            .parseSignedClaims(token);
        Claims c = jws.getPayload();
        UUID userId = UUID.fromString(c.getSubject());
        Role role = Role.valueOf(c.get("role", String.class));
        String phone = c.get("phone", String.class);
        return new ParsedToken(userId, role, phone, c.getExpiration().toInstant());
    }

    public record TokenPair(String accessToken, Instant expiresAt, long expiresInSeconds) {}

    public record ParsedToken(UUID userId, Role role, String phone, Instant expiresAt) {}
}
