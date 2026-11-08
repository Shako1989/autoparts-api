package az.autoparts.api.catalog.service;

import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.function.Predicate;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import az.autoparts.api.catalog.api.dto.VinLookupResponse;
import az.autoparts.api.catalog.api.dto.VinLookupResponse.CatalogMatch;
import az.autoparts.api.catalog.api.dto.VinLookupResponse.DecodedVehicle;
import az.autoparts.api.catalog.api.dto.VinLookupResponse.Engine;
import az.autoparts.api.catalog.api.dto.VinLookupResponse.MatchStatus;
import az.autoparts.api.catalog.api.mapper.VehicleMapper;
import az.autoparts.api.catalog.domain.FuelType;
import az.autoparts.api.catalog.domain.VehicleGeneration;
import az.autoparts.api.catalog.domain.VehicleMake;
import az.autoparts.api.catalog.domain.VehicleModel;
import az.autoparts.api.catalog.domain.VehicleVariant;
import az.autoparts.api.catalog.repo.VehicleGenerationRepository;
import az.autoparts.api.catalog.repo.VehicleMakeRepository;
import az.autoparts.api.catalog.repo.VehicleModelRepository;
import az.autoparts.api.catalog.repo.VehicleVariantRepository;
import az.autoparts.api.catalog.service.vpic.VpicClient;
import az.autoparts.api.catalog.service.vpic.VpicDecodeResult;
import lombok.RequiredArgsConstructor;

/**
 * Matching rules, in order:
 * <ol>
 *   <li>Make by name (case-insensitive) or slug.</li>
 *   <li>Model by vPIC model/series name or slug; else by a variant whose trim equals
 *       vPIC's model name (BMW decodes as "328i" while our model is "3 Series").</li>
 *   <li>Variants for model + model year. Hard rules drop any variant that contradicts
 *       what vPIC states (fuel, a different displacement figure, a different BMW-style
 *       designation) even if nothing is left. Soft rules (body type, trim tokens, a
 *       stated displacement) then prefer better matches but never empty the list.</li>
 *   <li>Generation: the one shared by all remaining variants, else the single
 *       generation whose year range contains the model year.</li>
 * </ol>
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
class VinLookupServiceImpl implements VinLookupService {

    private static final Logger log = LoggerFactory.getLogger(VinLookupServiceImpl.class);

    private final VpicClient vpic;
    private final VehicleMakeRepository makes;
    private final VehicleModelRepository models;
    private final VehicleGenerationRepository generations;
    private final VehicleVariantRepository variants;
    private final VehicleMapper vehicleMapper;

    @Override
    public VinLookupResponse lookup(String rawVin, Integer modelYearHint) {
        String vin = VinLookupSupport.normalizeVin(rawVin);
        Integer hint = VinLookupSupport.validateYear(modelYearHint);

        VpicDecodeResult d = vpic.decode(vin, hint);
        DecodedVehicle decoded = toDecoded(d);
        FuelType fuel = VinLookupSupport.inferFuel(d);
        String bodyType = VinLookupSupport.inferBodyType(d.bodyClass());

        if (d.make() == null) {
            return respond(vin, MatchStatus.NOT_DECODED, decoded, CatalogMatch.none(fuel, bodyType));
        }

        VehicleMake make = findMake(d.make()).orElse(null);
        if (make == null) {
            return respond(vin, MatchStatus.NOT_IN_CATALOG, decoded, CatalogMatch.none(fuel, bodyType));
        }

        VehicleModel model = findModel(make, d).orElse(null);
        if (model == null) {
            return respond(vin, MatchStatus.MAKE_ONLY, decoded,
                new CatalogMatch(vehicleMapper.toMakeResponse(make), null, null, List.of(), fuel, bodyType));
        }

        List<VehicleVariant> candidates = d.modelYear() == null
            ? List.of()
            : variants.findAllByModelIdAndYearOrderByTrimAsc(model.getId(), d.modelYear().shortValue());
        candidates = narrow(candidates, d, fuel, bodyType);
        VehicleGeneration generation = resolveGeneration(model, candidates, d.modelYear());

        MatchStatus status = candidates.isEmpty() ? MatchStatus.MODEL_ONLY
            : candidates.size() == 1 ? MatchStatus.EXACT
            : MatchStatus.AMBIGUOUS;

        return respond(vin, status, decoded, new CatalogMatch(
            vehicleMapper.toMakeResponse(make),
            vehicleMapper.toModelResponse(model),
            generation == null ? null : vehicleMapper.toGenerationResponse(generation),
            candidates.stream().map(vehicleMapper::toVariantResponse).toList(),
            fuel,
            bodyType));
    }

    private Optional<VehicleMake> findMake(String name) {
        Optional<VehicleMake> byName = makes.findByNameIgnoreCase(name);
        if (byName.isPresent()) return byName;
        return makes.findBySlug(VinLookupSupport.slugify(name));
    }

    private Optional<VehicleModel> findModel(VehicleMake make, VpicDecodeResult d) {
        for (String candidate : new String[] {d.model(), d.series()}) {
            if (candidate == null) continue;
            List<VehicleModel> byName = models.findAllByMakeIdAndNameIgnoreCase(make.getId(), candidate);
            if (!byName.isEmpty()) return Optional.of(byName.get(0));
            Optional<VehicleModel> bySlug = models.findByMakeIdAndSlug(make.getId(), VinLookupSupport.slugify(candidate));
            if (bySlug.isPresent()) return bySlug;
        }
        if (d.model() != null) {
            List<VehicleVariant> byTrim = variants.findAllByMakeIdAndTrimIgnoreCase(make.getId(), d.model());
            if (!byTrim.isEmpty()) {
                VehicleVariant best = byTrim.stream()
                    .filter(v -> d.modelYear() != null && v.getYear() == d.modelYear())
                    .findFirst()
                    .orElse(byTrim.get(0));
                return Optional.of(best.getGeneration().getModel());
            }
        }
        return Optional.empty();
    }

    private static List<VehicleVariant> narrow(
        List<VehicleVariant> all, VpicDecodeResult d, FuelType fuel, String bodyType
    ) {
        List<VehicleVariant> current = all;

        // Hard rules: a known value on both sides must agree.
        if (fuel != null) {
            current = current.stream()
                .filter(v -> v.getFuel() == null || v.getFuel() == fuel)
                .toList();
        }
        String litres = d.displacementL() == null ? null : VinLookupSupport.litres(d.displacementL());
        if (litres != null) {
            current = current.stream()
                .filter(v -> {
                    Set<String> stated = VinLookupSupport.litresIn(v.getTrim(), v.getEngineCode());
                    return stated.isEmpty() || stated.contains(litres);
                })
                .toList();
        }
        String designation = firstDesignation(d.model(), d.series());
        if (designation != null && current.stream().anyMatch(v -> VinLookupSupport.designation(v.getTrim()) != null)) {
            current = current.stream()
                .filter(v -> {
                    String own = VinLookupSupport.designation(v.getTrim());
                    return own == null || own.equals(designation);
                })
                .toList();
        }
        if (current.isEmpty()) return current;

        // Soft rules: prefer, never exclude.
        if (bodyType != null) {
            current = keepIfAny(current, v -> v.getBodyType() == null || v.getBodyType().equalsIgnoreCase(bodyType));
        }
        Set<String> wanted = VinLookupSupport.tokens(d.trim(), d.series(), d.model());
        if (!wanted.isEmpty()) {
            current = keepIfAny(current, v -> !Collections.disjoint(VinLookupSupport.tokens(v.getTrim()), wanted));
        }
        if (litres != null) {
            current = keepIfAny(current, v -> !VinLookupSupport.litresIn(v.getTrim(), v.getEngineCode()).isEmpty());
        }
        return current;
    }

    private static String firstDesignation(String... texts) {
        for (String text : texts) {
            String designation = VinLookupSupport.designation(text);
            if (designation != null) return designation;
        }
        return null;
    }

    private static List<VehicleVariant> keepIfAny(List<VehicleVariant> in, Predicate<VehicleVariant> keep) {
        List<VehicleVariant> out = in.stream().filter(keep).toList();
        return out.isEmpty() ? in : out;
    }

    private VehicleGeneration resolveGeneration(VehicleModel model, List<VehicleVariant> candidates, Integer year) {
        Set<UUID> generationIds = candidates.stream()
            .map(v -> v.getGeneration().getId())
            .collect(Collectors.toSet());
        if (generationIds.size() == 1) return candidates.get(0).getGeneration();
        if (!generationIds.isEmpty() || year == null) return null;
        List<VehicleGeneration> inRange = generations.findAllByModelIdOrderByYearFromAsc(model.getId()).stream()
            .filter(g -> g.getYearFrom() <= year && (g.getYearTo() == null || g.getYearTo() >= year))
            .toList();
        return inRange.size() == 1 ? inRange.get(0) : null;
    }

    private static VinLookupResponse respond(
        String vin, MatchStatus status, DecodedVehicle decoded, CatalogMatch match
    ) {
        log.debug("VIN lookup {} -> {} ({} {} {})", vin, status, decoded.make(), decoded.model(), decoded.year());
        return new VinLookupResponse(vin, status, decoded, match);
    }

    private static DecodedVehicle toDecoded(VpicDecodeResult d) {
        return new DecodedVehicle(
            d.make(), d.model(), d.modelYear(), d.series(), d.trim(), d.bodyClass(), d.vehicleType(), d.driveType(),
            new Engine(d.displacementL(), d.cylinders(), d.horsepower(), d.engineModel(),
                d.fuelPrimary(), d.fuelSecondary(), d.electrificationLevel()),
            d.plantCountry(), d.errorCode(), d.errorText());
    }
}
