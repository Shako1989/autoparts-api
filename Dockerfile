# syntax=docker/dockerfile:1.7

# ---------- build stage ----------
FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /workspace

# Cache the Gradle wrapper + dependencies before the source so dependency
# changes invalidate the cache, but source-only changes keep the cached layer.
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
RUN ./gradlew --no-daemon --version

COPY src ./src
RUN ./gradlew --no-daemon clean bootJar -x test

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
