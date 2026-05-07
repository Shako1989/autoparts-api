package az.autoparts.api.catalog.api.mapper;

import java.util.Collections;

import org.mapstruct.Context;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import az.autoparts.api.catalog.api.dto.CategoryResponse;
import az.autoparts.api.catalog.domain.Category;
import az.autoparts.api.common.locale.Locale;

@Mapper(componentModel = "spring")
public interface CategoryMapper {

    @Mapping(target = "parentId", source = "parent.id")
    @Mapping(target = "name", source = "category", qualifiedByName = "localiseCategory")
    @Mapping(target = "children", expression = "java(java.util.Collections.emptyList())")
    CategoryResponse toResponseFlat(Category category, @Context Locale locale);

    @Named("localiseCategory")
    default String localise(Category c, @Context Locale locale) {
        return LocalisedNameSupport.name(c, locale);
    }

    default CategoryResponse toResponseWithChildren(
        Category category,
        java.util.List<CategoryResponse> children,
        Locale locale
    ) {
        return new CategoryResponse(
            category.getId(),
            category.getParent() == null ? null : category.getParent().getId(),
            category.getSlug(),
            LocalisedNameSupport.name(category, locale),
            category.getIconUrl(),
            category.getSortOrder(),
            children == null ? Collections.emptyList() : children
        );
    }
}
