FROM eclipse-temurin:21-jdk
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar

ENV HOSTNAME=localhost

ENTRYPOINT ["java", "-DEUREKA_INSTANCE_HOSTNAME=${HOSTNAME}", "-jar", "app.jar"]

EXPOSE 3150