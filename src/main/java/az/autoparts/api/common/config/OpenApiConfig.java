package az.autoparts.api.common.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    OpenAPI autoPartsOpenAPI() {
        return new OpenAPI().info(new Info()
            .title("AutoParts.az API")
            .description("Backend API for AutoParts.az marketplace")
            .version("v1"));
    }
}
