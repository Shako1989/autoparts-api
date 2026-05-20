package az.autoparts.api.identity.domain;

import java.math.BigDecimal;
import java.util.UUID;

import az.autoparts.api.common.auditing.AuditableEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "seller_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SellerProfile extends AuditableEntity {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "user_id", nullable = false, unique = true)
    private UUID userId;

    @Column(name = "display_name", nullable = false, length = 160)
    private String displayName;

    @Column(name = "legal_name", length = 255)
    private String legalName;

    @Column(name = "tax_id", length = 40)
    private String taxId;

    @Column(length = 80)
    private String city;

    @Column(columnDefinition = "text")
    private String address;

    @Column(name = "contact_phone", length = 20)
    private String contactPhone;

    @Column(length = 20)
    private String whatsapp;

    @Column(columnDefinition = "text")
    private String bio;

    @Enumerated(EnumType.STRING)
    @Column(name = "kyc_status", nullable = false, length = 20)
    private KycStatus kycStatus;

    @Column(name = "rating_avg", nullable = false, precision = 3, scale = 2)
    private BigDecimal ratingAvg;

    @Column(name = "rating_count", nullable = false)
    private int ratingCount;
}
