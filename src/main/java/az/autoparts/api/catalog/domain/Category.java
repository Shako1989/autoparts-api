package az.autoparts.api.catalog.domain;

import java.util.UUID;

import az.autoparts.api.common.auditing.AuditableEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "categories")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Category extends AuditableEntity {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id")
    private Category parent;

    @Column(nullable = false, length = 120, unique = true)
    private String slug;

    @Column(name = "name_az", nullable = false, length = 160)
    private String nameAz;

    @Column(name = "name_ru", nullable = false, length = 160)
    private String nameRu;

    @Column(name = "name_en", nullable = false, length = 160)
    private String nameEn;

    @Column(name = "icon_url", length = 255)
    private String iconUrl;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;
}
