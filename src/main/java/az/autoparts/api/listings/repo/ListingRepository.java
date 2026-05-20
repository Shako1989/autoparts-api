package az.autoparts.api.listings.repo;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import az.autoparts.api.listings.domain.Listing;
import az.autoparts.api.listings.domain.ListingStatus;

public interface ListingRepository extends JpaRepository<Listing, UUID> {

    @Query("select l from Listing l where l.partId = :partId and l.status = 'ACTIVE' order by l.priceMinor asc")
    Page<Listing> findActiveByPartId(@Param("partId") UUID partId, Pageable pageable);

    Optional<Listing> findByIdAndSellerId(UUID id, UUID sellerId);

    Page<Listing> findAllBySellerId(UUID sellerId, Pageable pageable);

    Page<Listing> findAllBySellerIdAndStatus(UUID sellerId, ListingStatus status, Pageable pageable);

    @Query("""
        select l.partId as partId,
               count(l.id) as activeCount,
               min(l.priceMinor) as minPriceMinor,
               min(l.currency) as currency
          from Listing l
         where l.partId in :partIds and l.status = 'ACTIVE'
         group by l.partId
        """)
    List<PartListingStatsProjection> findPartListingStats(@Param("partIds") Collection<UUID> partIds);

    interface PartListingStatsProjection {
        UUID getPartId();
        long getActiveCount();
        Long getMinPriceMinor();
        String getCurrency();
    }
}
