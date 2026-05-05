# autoparts-api

Backend service for AutoParts.az — Spring Boot 3.3 + Java 21 + PostgreSQL 16 + Meilisearch.

See the project brief at `../AutoParts_az_MVP_Developer_Brief.md` for the full architecture and roadmap.

## Prerequisites

- Java 21 (Eclipse Temurin recommended)
- Local infra services running — start them from the `autoparts-infra` repo:
  ```
  cd ../autoparts-infra && docker-compose up -d
  ```

## Run locally

```
./gradlew bootRun --args='--spring.profiles.active=local'
```

Then:

- Health check: <http://localhost:8080/actuator/health>
- Swagger UI: <http://localhost:8080/swagger-ui.html>

## Test

```
./gradlew check
```

Integration tests use Testcontainers (Docker required).

## Module layout

Top-level packages under `az.autoparts`: `identity`, `catalog`, `listings`, `search`, `orders`, `payments`, `shipping`, `notifications`, `admin`, `common`. Cross-module communication goes through public service interfaces only — never direct repository access from another module. See `CONTRIBUTING.md`.
