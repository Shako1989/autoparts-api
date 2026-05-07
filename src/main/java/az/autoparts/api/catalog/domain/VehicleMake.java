package az.autoparts.api.catalog.domain;

import java.util.UUID;

import az.autoparts.api.common.auditing.AuditableEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "vehicle_makes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VehicleMake extends AuditableEntity {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false, length = 80, unique = true)
    private String name;

    @Column(nullable = false, length = 80, unique = true)
    private String slug;

    @Column(name = "logo_url", length = 255)
    private String logoUrl;

    @Column(nullable = false)
    private int popularity;
}
