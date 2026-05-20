package az.autoparts.api.listings.domain;

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
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(
    name = "listing_photos",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_listing_photos_position",
        columnNames = {"listing_id", "position"}
    )
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ListingPhoto extends AuditableEntity {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "listing_id", nullable = false)
    private Listing listing;

    @Column(nullable = false, length = 512)
    private String url;

    @Column(name = "s3_key", nullable = false, length = 255)
    private String s3Key;

    @Column(nullable = false)
    private int position;

    private Integer width;

    private Integer height;
}
