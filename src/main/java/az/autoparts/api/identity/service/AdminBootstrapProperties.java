package az.autoparts.api.identity.service;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Allowlist of phone numbers that should auto-promote to STAFF on first OTP
 * verify. Phones must be in E.164 format (same as users.phone).
 */
@ConfigurationProperties(prefix = "app.admin")
public record AdminBootstrapProperties(List<String> phones) {

    public boolean isAllowlisted(String phone) {
        return phones != null && phones.contains(phone);
    }
}
