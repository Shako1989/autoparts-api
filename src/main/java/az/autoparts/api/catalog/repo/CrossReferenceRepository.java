package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.CrossReference;

public interface CrossReferenceRepository extends JpaRepository<CrossReference, UUID> {

    List<CrossReference> findAllByNumberAOrNumberB(String numberA, String numberB);
}
