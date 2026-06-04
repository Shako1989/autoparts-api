package az.autoparts.api.catalog.api.admin.dto;

import java.util.UUID;

import az.autoparts.api.catalog.domain.PartNumberType;

public record AdminPartNumberEntry(
    UUID id,
    String number,
    PartNumberType type,
    String source
) {}
