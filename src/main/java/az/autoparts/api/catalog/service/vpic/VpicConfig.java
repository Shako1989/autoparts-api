package az.autoparts.api.catalog.service.vpic;

import org.springframework.boot.autoconfigure.cache.RedisCacheManagerBuilderCustomizer;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.serializer.Jackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext.SerializationPair;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import com.fasterxml.jackson.databind.ObjectMapper;

@Configuration
@EnableConfigurationProperties(VpicProperties.class)
class VpicConfig {

    static final String HTTP_CLIENT = "vpicHttpClient";

    @Bean(HTTP_CLIENT)
    RestClient vpicHttpClient(RestClient.Builder builder, VpicProperties props) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(props.connectTimeout());
        factory.setReadTimeout(props.readTimeout());
        return builder
            .baseUrl(props.baseUrl())
            .requestFactory(factory)
            .build();
    }

    /**
     * Decoded VINs are immutable manufacturer data, so they are cached for a
     * long time as plain JSON (readable in redis-cli, no Java serialization).
     */
    @Bean
    RedisCacheManagerBuilderCustomizer vpicCacheCustomizer(VpicProperties props, ObjectMapper objectMapper) {
        return builder -> builder.withCacheConfiguration(
            VpicRestClient.CACHE,
            RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(props.cacheTtl())
                .disableCachingNullValues()
                .serializeValuesWith(SerializationPair.fromSerializer(
                    new Jackson2JsonRedisSerializer<>(objectMapper, VpicDecodeResult.class))));
    }
}
