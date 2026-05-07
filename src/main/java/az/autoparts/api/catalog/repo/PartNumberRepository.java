package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.PartNumber;

public interface PartNumberRepository extends JpaRepository<PartNumber, UUID> {

    List<PartNumber> findAllByNumber(String number);

    List<PartNumber> findAllByPartId(UUID partId);
}
