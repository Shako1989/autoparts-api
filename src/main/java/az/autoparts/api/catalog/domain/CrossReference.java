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
@Table(name = "cross_references")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CrossReference extends AuditableEntity {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "number_a", nullable = false, length = 80)
    private String numberA;

    @Column(name = "number_b", nullable = false, length = 80)
    private String numberB;

    @Column(length = 80)
    private String source;

    @Column(nullable = false)
    private short confidence;
}
