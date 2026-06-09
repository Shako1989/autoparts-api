package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import az.autoparts.api.catalog.domain.DiagramCallout;

public interface DiagramCalloutRepository extends JpaRepository<DiagramCallout, UUID> {

    @EntityGraph(attributePaths = {"part", "part.category"})
    List<DiagramCallout> findAllByDiagramId(UUID diagramId);

    @EntityGraph(attributePaths = {"diagram"})
    List<DiagramCallout> findAllByPartId(UUID partId);
}
