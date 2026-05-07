package az.autoparts.api.catalog.repo;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import az.autoparts.api.catalog.domain.VehicleVariant;

public interface VehicleVariantRepository extends JpaRepository<VehicleVariant, UUID> {

    List<VehicleVariant> findAllByModelIdAndYearOrderByTrimAsc(UUID modelId, short year);

    @Query("select distinct v.year from VehicleVariant v where v.model.id = :modelId order by v.year")
    List<Short> findDistinctYearsByModelId(UUID modelId);
}
