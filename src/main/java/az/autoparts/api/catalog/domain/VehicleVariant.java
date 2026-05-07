package az.autoparts.api.catalog.domain;

import java.util.UUID;

import az.autoparts.api.common.auditing.AuditableEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(
    name = "vehicle_variants",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_vehicle_variants",
        columnNames = {"model_id", "year", "trim", "engine_code"}
    )
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VehicleVariant extends AuditableEntity {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "model_id", nullable = false)
    private VehicleModel model;

    @Column(nullable = false)
    private short year;

    @Column(length = 120)
    private String trim;

    @Column(name = "engine_code", length = 60)
    private String engineCode;

    @Column(name = "body_type", length = 40)
    private String bodyType;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private FuelType fuel;
}
