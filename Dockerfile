FROM eclipse-temurin:23-jre-alpine

RUN apk update && \
    apk add --no-cache expat=2.6.4-r0 openssl=3.3.2-r1

COPY target/spring-petclinic-*.jar /opt/spring-petclinic/spring-petclinic.jar

EXPOSE 8080/tcp

ENTRYPOINT [ "java", "-jar", "/opt/spring-petclinic/spring-petclinic.jar" ]
