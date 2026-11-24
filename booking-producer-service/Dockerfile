
# Stage 1: Build
FROM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /workspace

COPY . .

RUN mvn -B -ntp -pl booking-producer-service -am \
    clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:11-jre

WORKDIR /app

COPY --from=build --chown=10001:10001 \
    /workspace/booking-producer-service/target/booking-producer-service-0.0.1-SNAPSHOT.jar \
    app.jar

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
