package az.autoparts.api.listings.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.listings.domain.ListingPhoto;

public interface ListingPhotoRepository extends JpaRepository<ListingPhoto, UUID> {

    List<ListingPhoto> findAllByListingIdOrderByPositionAsc(UUID listingId);

    void deleteByListingIdAndId(UUID listingId, UUID id);
}
