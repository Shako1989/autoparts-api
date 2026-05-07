package az.autoparts.api.common.pagination;

import java.util.List;

import org.springframework.data.domain.Page;

/**
 * Wire format for paginated responses across the API.
 * Stable shape so the frontend doesn't depend on Spring's internal Page serialization.
 */
public record PageResponse<T>(
    List<T> items,
    int page,
    int size,
    long total
) {
    public static <T> PageResponse<T> of(Page<T> page) {
        return new PageResponse<>(page.getContent(), page.getNumber(), page.getSize(), page.getTotalElements());
    }

    public <R> PageResponse<R> map(java.util.function.Function<T, R> mapper) {
        return new PageResponse<>(items.stream().map(mapper).toList(), page, size, total);
    }
}
