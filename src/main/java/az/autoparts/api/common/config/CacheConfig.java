package az.autoparts.api.common.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.Cache;
import org.springframework.cache.annotation.CachingConfigurer;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.context.annotation.Configuration;

/**
 * Enables Spring's cache abstraction. Boot auto-configures a Redis-backed
 * {@code CacheManager} because spring-data-redis is on the classpath.
 *
 * Cache failures are logged and treated as misses, so an unreachable Redis
 * degrades to uncached calls instead of failing requests. Nothing in the app
 * depends on a cache hit for correctness.
 */
@Configuration
@EnableCaching
public class CacheConfig implements CachingConfigurer {

    private static final Logger log = LoggerFactory.getLogger(CacheConfig.class);

    @Override
    public CacheErrorHandler errorHandler() {
        return new CacheErrorHandler() {
            @Override
            public void handleCacheGetError(RuntimeException ex, Cache cache, Object key) {
                warn("get", cache, ex);
            }

            @Override
            public void handleCachePutError(RuntimeException ex, Cache cache, Object key, Object value) {
                warn("put", cache, ex);
            }

            @Override
            public void handleCacheEvictError(RuntimeException ex, Cache cache, Object key) {
                warn("evict", cache, ex);
            }

            @Override
            public void handleCacheClearError(RuntimeException ex, Cache cache) {
                warn("clear", cache, ex);
            }
        };
    }

    private static void warn(String operation, Cache cache, RuntimeException ex) {
        log.warn("Cache {} failed on '{}'; continuing without cache: {}", operation, cache.getName(), ex.toString());
    }
}
