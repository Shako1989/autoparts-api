# syntax=docker/dockerfile:1.7

# ---------- build stage ----------
# The official Gradle image ships Gradle 8.14.4, the same version the wrapper
# pins, so the image build never downloads a Gradle distribution. That
# download (services.gradle.org -> GitHub Releases) has timed out and 504'd
# both in CI and on the production VM.
FROM gradle:8.14.4-jdk21 AS build
WORKDIR /workspace

# Resolve dependencies before copying the source so a source-only change
# reuses the cached dependency layer.
COPY settings.gradle.kts build.gradle.kts ./
RUN gradle --no-daemon dependencies --configuration compileClasspath > /dev/null \
 && gradle --no-daemon dependencies --configuration runtimeClasspath > /dev/null

COPY src ./src
RUN gradle --no-daemon clean bootJar -x test

# ---------- runtime stage ----------
FROM eclipse-temurin:21-jre-jammy
RUN useradd --create-home --shell /bin/bash --uid 1001 app
USER app
WORKDIR /home/app

COPY --from=build --chown=app:app /workspace/build/libs/*.jar app.jar

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"
ENV SPRING_PROFILES_ACTIVE=prod
EXPOSE 8080

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
