# FIXES.md — eCabs DevOps Challenge

This document records issues identified while reviewing, containerizing, and testing the booking producer, booking consumer, RabbitMQ, and local H2 storage. It distinguishes implemented changes from items requiring further verification or production remediation.

> **Scope:** Application, messaging, Docker Compose, build, and local persistence findings only. Terraform design and validation discussions are intentionally excluded.
>
> **Status note:** Statuses reflect the implementation and testing described during the challenge; this document is not an independent audit of the latest repository contents. “Implemented” does not imply production readiness.

## Findings summary

| ID | Priority | Finding | Status |
|---|---|---|---|
| F01 | Critical | In-memory H2 database loses bookings on restart | Mitigated locally; production database deferred |
| F02 | High | RabbitMQ hostname assumes `localhost` | Implemented |
| F03 | High | Possible message loss or repeated delivery on consumer rejection | Open — behaviour not yet confirmed |
| F04 | High | Sensitive credentials packaged in Maven artifacts | Mitigated; artifact verification outstanding |
| F05 | High | Unsupported Spring Boot 2.3.1 and limited secret-loading support | Workaround implemented; upgrade deferred |
| F06 | High | Exception when editing a non-existent booking | Open |
| F07 | Medium | RabbitMQ credentials not explicitly externalized | Implemented |
| F08 | Medium | H2 persistent-volume permissions | Fix implemented |
| F09 | Low | Bean-definition overriding enabled | Open — investigate need |
| F10 | Low | Limited visibility into database operations | Local diagnostic logging added; production observability deferred |
| F11 | Low | Hardcoded datasource settings reduce portability | Configurable |

## Detailed findings

### F01 — Critical: In-memory H2 database loses bookings on restart

**Finding:** The consumer originally used `jdbc:h2:mem:ecabs`. Data stored in this in-memory database is lost when the consumer process stops.

**Risk:** Bookings could disappear following application restarts, container replacement, or failure.

**Remediation:**
- Changed local storage to file-backed H2 (`jdbc:h2:file:/data/ecabs`).
- Added a named Docker volume, `booking_data`, mounted at `/data` in the consumer.
- Made datasource configuration overridable at runtime.
- Retained PostgreSQL (for example, managed Cloud SQL) as a production architecture recommendation rather than introducing a database migration during the challenge.

**Verification:** Create a booking, restart and  then verify that the same booking is still present. Ensure Hibernate schema settings do not drop existing data on startup.

**Status:** Mitigated for local development with file-backed H2. Production-grade durable storage is deferred.

### F02 — High: RabbitMQ hostname assumes `localhost`

**Finding:** A RabbitMQ hostname fixed to `localhost` does not work when the broker is running in a separate Compose container.

**Risk:** Producer or consumer services may fail to connect to RabbitMQ after containerization.

**Remediation:** Externalized the host and port configuration and supplied the Compose service hostname (`rabbitmq`) at runtime.

**Verification:** Start the Compose stack and confirm that both producer and consumer connect to `rabbitmq:5672` and successfully exchange a test booking message.

**Status:** Configuration change implemented; confirm against the final Compose deployment.

### F03 — High: Possible message loss or repeated delivery on consumer rejection

**Finding:** Message failure behaviour was not established. An exception during consumer processing could result in requeueing, repeated delivery, rejection, or message loss, depending on acknowledgement and listener settings.

**Risk:** Failed booking operations may be lost or repeatedly retried without a controlled recovery path.

**Remediation:** Inspect consumer acknowledgement and rejection handling, retry configuration, queue durability, and dead-letter handling. Define explicit treatment for transient and permanent failures rather than assuming a dead-letter queue or retry policy already exists.

**Verification:** Deliberately trigger a processing failure and observe acknowledgement/requeue/dead-letter behaviour, queue depth, and consumer logs.

**Status:** Open — potential issue; not yet verified as actual message loss.

### F04 — High: Sensitive credentials packaged in Maven artifacts

**Finding:** Spring Boot configuration files containing hardcoded credentials were included in executable JAR artifacts by Maven.

**Risk:** Secrets could be extracted from distributed JAR files or from container images containing those artifacts.

**Remediation:**
- Removed hardcoded secrets from application resources and adopted runtime configuration.
- Used externally mounted Docker Compose secret/property files for sensitive values.
- Kept secret material out of version control and Docker build contexts; any genuinely exposed credentials should be rotated.

**Verification:** Rebuild the JAR files and Docker images; inspect `BOOT-INF/classes/` and the image contents for actual credential values, and verify runtime secret loading.

**Status:** Mitigation described and adopted.

### F05 — High: Unsupported Spring Boot 2.3.1 and limited secret-loading support

**Finding:** The supplied applications use Spring Boot `2.3.1.RELEASE`, which does not support `spring.config.import=configtree:` and is no longer supported.

**Risk:** An unsupported framework creates maintenance and security exposure. Modern configuration-tree integration cannot be used without a framework upgrade.

**Remediation:**
- Kept the existing framework version for the challenge to avoid unrelated migration risk.
- Loaded mounted Compose secret property files using `SPRING_CONFIG_ADDITIONAL_LOCATION`, for example `file:/run/secrets/producer.properties`.
- Deferred a tested upgrade to a supported Spring Boot release and compatible Java version; future deployments may then use `configtree`.

**Verification:** Confirm that the producer and consumer read their respective mounted secret files without embedding credentials in JARs. When upgrading, rerun build and integration tests and validate the new configuration mechanism.

**Status:** Compatible workaround implemented; supported-framework upgrade deferred.

### F06 — High: Unhandled exception when editing a non-existent booking

**Finding:** Submitting an EDIT request for an unknown booking ID returned HTTP `202 Accepted` from the producer, while the consumer logged `java.util.NoSuchElementException: No value present`.

**Risk:** Invalid updates fail in the background and may be retried, discarded, or become difficult to diagnose depending on message handling.

**Remediation:** Investigate the update path for unsafe `Optional.get()` usage or equivalent missing-record handling. Handle missing bookings explicitly, log the processing outcome, and define acknowledgement/rejection behaviour.

**Verification:** Submit an update for a non-existent ID and check that the consumer handles it predictably without an uncontrolled exception; observe the message's final outcome.

**Note:** For an asynchronous API, HTTP `202` means *accepted for processing*, not *successfully updated*. The response code alone does not prove an API defect.

**Status:** Open.

### F07 — Medium: RabbitMQ credentials not explicitly externalized

**Finding:** Broker credentials initially lacked a clearly documented runtime configuration mechanism.

**Risk:** Default, hardcoded, or inconsistently provisioned credentials can cause connection failures and unnecessary secret exposure.

**Remediation:** Provided non-sensitive connection settings through Compose environment variables and sensitive values through per-service mounted secret/property files. This is related to, but distinct from, the artifact-packaging issue in F04.

**Verification:** Confirm the broker, producer, and consumer use matching credentials; test successful authentication without committing or packaging real passwords.

**Status:** Implemented in the local configuration approach; final end-to-end check recommended.

### F08 — Medium: H2 persistent-volume permissions

**Finding:** After enabling file-backed H2, the consumer failed to write files under `/data` with `Permission denied`.

**Root cause:** The consumer runs as non-root user `10001:10001`, while the named volume did not initially have compatible ownership.

**Remediation:** Introduced a lightweight BusyBox initialization service that sets the required ownership before the consumer starts when persistent H2 is configured. Used a Compose startup dependency and retained non-root execution for the consumer.

**Verification:** Start the stack with a newly created volume, confirm the initialization service succeeds and no permission errors occur, then confirm booking persistence after container recreation.

**Status:** Fix implemented; verification of clean startup and recreation should be recorded.

### F09 — Low: Bean-definition overriding enabled

**Finding:** Bean-definition overriding was enabled in the application configuration without an established need.

**Risk:** Unintentional duplicate bean definitions may be masked rather than failing early.

**Remediation:** Determine whether overriding is required; disable it if the application starts and tests pass without it.

**Verification:** Remove or disable the setting, rebuild both services, and run tests and startup checks for bean conflicts.

**Status:** Open — investigation pending.

### F10 — Low: Limited visibility into database operations

**Finding:** It was difficult to confirm whether the consumer was executing database operations after receiving messages.

**Risk:** Persistence failures and processing issues are harder to diagnose without adequate logs.

**Remediation:** Enabled temporary Hibernate SQL and bind-parameter logging for local troubleshooting through `JAVA_TOOL_OPTIONS`:

```yaml
environment:
  JAVA_TOOL_OPTIONS: >-
    -Dlogging.level.org.hibernate.SQL=DEBUG
    -Dlogging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

**Verification:** Submit a booking and inspect the consumer's message-processing and Hibernate SQL logs. An emitted SQL `INSERT` does not, on its own, prove a successful database commit.

**Status:** Local diagnostic aid implemented. Disable verbose bind-parameter TRACE outside controlled troubleshooting because it may expose booking data; structured processing logs and metrics remain future improvements.

### F11 — Low: Hardcoded datasource configuration limits portability

**Finding:** The consumer's datasource configuration was tied directly to H2 settings.

**Risk:** Switching between local memory storage, file-backed H2, and a future production database would require unnecessary configuration changes.

**Remediation:** Made datasource URL and credentials configurable through Spring Boot properties and runtime overrides such as `SPRING_DATASOURCE_URL`. Kept database-driver/schema migration work separate from simple configuration portability.

**Verification:** Confirm that the default local configuration works and that the Compose datasource override selects `jdbc:h2:file:/data/ecabs`. Verify that credentials are supplied securely when required.

**Status:** Configuration approach implemented.
