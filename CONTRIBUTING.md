# Contributing — autoparts-api

Conventions distilled from the project brief §6. Apply on every PR.

## Code

- DTOs are `record` types with Bean Validation annotations. Never expose JPA entities to controllers.
- Controllers do no business logic — they call services. Services take and return DTOs.
- Use MapStruct for entity ↔ DTO mapping. Never write mapping code by hand.
- All public service methods are `@Transactional` (read-only by default; write methods opt in).
- Avoid Hibernate lazy loading across module boundaries. Use explicit `@EntityGraph` or projections.
- Cross-module access only through public service interfaces — never another module's repository.

## Money & time

- Money is `bigint` minor units (qəpik) on the wire and in the DB. Never `double`/`float` for money.
- Use the `Money` value object on the backend; arithmetic throws on currency mismatch.
- Timestamps are `timestamptz` in the DB and `Instant` / `OffsetDateTime` in Java. Never `LocalDateTime` for events.

## Logging

- SLF4J only.
- INFO for state changes, ERROR for unhandled exceptions.
- **Never log request/response bodies for `/auth/*` or `/payments/*`.**

## Tests

- Each controller has at least one `@SpringBootTest` integration test covering happy path + one failure path.
- Authorization rules must be tested (a seller cannot read another seller's data).
- Testcontainers for Postgres / Redis / Meilisearch — no in-memory H2.

## Security

- All write endpoints use `Authorization: Bearer …` JWT — no cookies for state changes.
- `@PreAuthorize` on every non-public endpoint.
