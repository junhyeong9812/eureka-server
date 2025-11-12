# Eureka Server 학습용 README

## 1. 개요

Eureka Server는 분산 환경에서 각 서비스의 위치(IP/PORT)를 중앙에서 관리하는 **서비스 레지스트리**입니다. 마이크로서비스는 스케일 인/아웃, 재시작 등의 이유로 주소가 변경될 수 있는데, 이런 동적인 환경에서 서비스 간 통신을 안정적으로 유지하기 위해 Eureka가 사용됩니다.

Eureka Server는 서비스 등록(Register)과 서비스 조회(Discovery)를 담당하며, Eureka Client는 자신을 서버에 등록하고, 다른 서비스 호출 시 Eureka Server를 통해 대상 서비스를 조회합니다.

또한 클라이언트 내부에는 **Ribbon** 이라는 **클라이언트 사이드 로드밸런서**가 존재하여, Eureka에서 조회된 서비스 인스턴스 목록 중 하나를 선택하여 호출합니다.

---

## 2. 프로젝트 구성

### 의존성 설정 (build.gradle)

```gradle
dependencies {
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-server'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    runtimeOnly 'io.micrometer:micrometer-registry-prometheus' // Prometheus 모니터링
    implementation 'com.github.loki4j:loki-logback-appender:2.0.0' // Loki 로그 수집
}
```

---

## 3. Eureka Server 활성화 코드

src/main/java/.../EurekaServerApplication.java

```java
package com.codefactory.eurekaserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@EnableEurekaServer
@SpringBootApplication
public class EurekaServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(EurekaServerApplication.class, args);
    }

}
```

`@EnableEurekaServer` 어노테이션은 해당 애플리케이션을 Eureka Server로 동작하도록 활성화합니다.

---

## 4. Eureka Server 설정 파일

src/main/resources/application.yml

```yaml
server:
  port: 3101

spring:
  application:
    name: eureka-server

eureka:
  instance:
    hostname: localhost
  client:
    registerWithEureka: false
    fetchRegistry: false
    serviceUrl:
      defaultZone: http://${eureka.instance.hostname}:${server.port}/eureka/

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    prometheus:
      enabled: true
```

### 주요 설정 설명

| 설정                                          | 설명                               |
| ------------------------------------------- | -------------------------------- |
| `hostname`                                  | Eureka 서버의 호스트 이름 (현재 로컬 환경)     |
| `registerWithEureka: false`                 | 서버는 레지스트리 역할이므로 자기 자신을 등록할 필요 없음 |
| `fetchRegistry: false`                      | 서버는 레지스트리 정보를 외부에서 가져올 필요 없음     |
| `defaultZone`                               | 클라이언트가 Eureka Server에 접속할 URL    |
| `management.endpoints.web.exposure.include` | Actuator 모니터링 엔드포인트 공개           |

---

## 5. Ribbon을 통한 클라이언트 사이드 로드밸런싱

Eureka Client 애플리케이션은 Eureka Server에게 현재 살아있는 서비스 인스턴스 목록을 조회합니다. 이를 기반으로 **Ribbon** 이 인스턴스 목록에서 하나를 선택하여 요청을 분배합니다.

### 흐름도

```
Client → Eureka Server (서비스 목록 요청)
Client ← Eureka Server (인스턴스 리스트)
Client-side Ribbon → 인스턴스 중 하나 선택하여 호출
```

즉, 로드밸런싱이 **서버 측이 아니라 클라이언트 내부에서 수행되는 것**이 특징입니다.

---

## 6. Prometheus + Grafana 모니터링 설정

### 1) Prometheus 의존성 추가 (이미 위에 포함됨)

```gradle
runtimeOnly 'io.micrometer:micrometer-registry-prometheus'
```

### 2) Actuator Prometheus 엔드포인트 활성화 (이미 위에 포함됨)

Prometheus는 다음 URL에서 메트릭을 수집할 수 있습니다.

```
http://localhost:3101/actuator/prometheus
```

---

## 7. Loki + Grafana 로그 수집 설정

### 1) LokI Appender 의존성 추가

```gradle
implementation 'com.github.loki4j:loki-logback-appender:2.0.0'
```

### 2) logback.xml 작성

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <appender name="LOKI" class="com.github.loki4j.logback.Loki4jAppender">
        <http>
            <url>https://{loki-server-address}/loki/api/v1/push</url>
        </http>
        <message class="com.github.loki4j.logback.JsonLayout" />
    </appender>

    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="LOKI"/>
        <appender-ref ref="STDOUT"/>
    </root>
</configuration>
```

---

## 8. Eureka Client 설정

### 클라이언트 프로젝트 build.gradle

```gradle
dependencies {
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
}
```

### 클라이언트 application.yml 설정

```yaml
spring:
  application:
    name: order-service

eureka:
  client:
    register-with-eureka: true
    fetch-registry: true
    service-url:
      defaultZone: http://localhost:3101/eureka/
```

| 설정                           | 설명                                |
| ---------------------------- | --------------------------------- |
| `register-with-eureka: true` | 해당 서비스가 Eureka Server에 자기 자신을 등록함 |
| `fetch-registry: true`       | Eureka Server로부터 다른 서비스 목록을 가져옴   |
| `defaultZone`                | Eureka Server 주소                  |

---

## 9. Config Server와 Eureka 연동 설정

Eureka를 통해 Config Server를 서비스 디스커버리 방식으로 연결할 수도 있습니다. Config Server가 Eureka에 등록되어 있다면, 클라이언트는 직접 URL을 지정하지 않고 Eureka를 통해 Config Server의 위치를 자동으로 조회합니다.

### 클라이언트 application.yml 예시

```yaml
spring:
  application:
    name: hub-service
  config:
    import: 'optional:configserver:'
  cloud:
    config:
      discovery:
        enabled: true
        service-id: config-server
```

| 설정                        | 설명                                    |
| ------------------------- | ------------------------------------- |
| `config.import`           | Config Server를 외부 설정소스로 사용하도록 지정      |
| `discovery.enabled: true` | Eureka를 통해 Config Server 위치 자동 탐색 활성화 |
| `service-id`              | Eureka에 등록된 Config Server의 서비스 이름     |

---

## 10. 정리

| 역할            | 구성 요소         | 설명                                    |
| ------------- | ------------- | ------------------------------------- |
| 서비스 레지스트리     | Eureka Server | 서비스 등록 및 조회 담당                        |
| 서비스 자기등록 / 조회 | Eureka Client | 서버에 등록하고 서비스 목록 조회                    |
| 로드밸런싱         | Ribbon        | Eureka에서 조회한 인스턴스 목록 기반 클라이언트 측 로드밸런싱 |
| 메트릭 수집        | Prometheus    | `/actuator/prometheus` 기반 메트릭 수집      |
| 로그 수집         | Loki          | 로그 스트림을 Loki 서버로 전송 후 Grafana로 시각화    |

---

Eureka를 중심으로 한 서비스 디스커버리, 로드밸런싱, 모니터링 환경을 구축함으로써 MSA 환경에서 서비스 확장성과 장애 대응성이 향상됩니다.
