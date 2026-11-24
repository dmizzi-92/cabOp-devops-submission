# DECISIONS.md — eCabs DevOps Coding Challenge

**Last consolidated:** 19 November 2026

This document records the significant technical choices made for the assignment, including their rationale, limitations, and deliberately deferred improvements. It complements `README.md` (setup and operation), `FIXES.md` (findings and remediation), and the Terraform/Kubernetes configuration (implementation).

> **Status convention:** **Accepted** means the approach has been chosen; it does **not** by itself mean that every related change has been implemented, tested, or deployed. Where relevant, *implementation scope* distinguishes local work from proposed cloud architecture. No live GKE deployment is claimed.

## Decision Summary

| ID | Area | Decision |
| --- | --- | --- |
| D-001 | Build baseline | Record the existing Maven integration-test results before making changes and rerun the tests in CI. |
| D-002 | Java and Spring Boot | Retain Java 11 and the supplied Spring Boot version during containerization. |
| D-003 | Maven versioning | Keep the existing `SNAPSHOT` versions for the assignment. |
| D-004 | Container images | Use separate multi-stage Dockerfiles for the producer and consumer, with non-root runtimes. |
| D-005 | Deployment target | Use Docker Compose locally. Target GKE Autopilot with the producer, consumer, and a single-replica, persistent RabbitMQ broker on the same cluster. |
| D-006 | Configuration and secrets | Externalize runtime settings and mount credentials as file-backed Compose secrets. |
| D-007 | Booking storage | Persist file-backed H2 on a named volume locally and propose MongoDB Atlas for production. |
| D-008 | Volume permissions | Use a short-lived BusyBox service to set H2 volume ownership before the consumer starts. |
| D-009 | Cloud container runtime | Store application images in Artifact Registry and rely on the GKE Autopilot-managed container runtime. |
| D-010 | Infrastructure as code | Define GCP infrastructure in Terraform and application workloads in Kubernetes manifests. |
| D-011 | CI scope | Run Maven builds and tests, validate Compose, and build container images. Keep cloud deployment outside the assignment’s CI scope. |
| D-012 | CI smoke test | Start the Compose stack and verify that the producer API returns the expected response to a sample booking request. |
| D-013 | Image pinning | Keep versioned image tags and defer SHA-256 digest pinning. |
| D-014 | Shared Maven module | Build `booking-contract` through the Maven reactor and defer publishing it to a private Maven repository. |
| D-015 | Defer Static Analysis and Linting in CI | Prioritize core build, test, and runtime validation; introduce dedicated linting and static analysis tools as a future CI enhancement.|

## D-001 — Establish a Maven build-and-test baseline

**Status:** Accepted — baseline recorded.

**Context:** The supplied project contains Maven modules for the booking producer, booking consumer, and shared `booking-contract` library. A baseline helps distinguish existing application defects from regressions introduced during containerization.

**Decision:** Record existing Maven integration-test results before changing the build or runtime environment and rerun tests as part of CI.

**Rationale:** Establishes a known-good reference and makes subsequent changes easier to troubleshoot.

**Recorded evidence (14 November 2026):** Producer: **4 tests passed**; consumer: **5 tests passed**; **0 failures, errors or skips** across the two reports. This is a baseline, not evidence of complete end-to-end behaviour in containers.

## D-002 — Retain the supplied Java and Spring Boot versions during containerization

**Status:** Accepted.

**Context:** The project uses Java 11 and Spring Boot 2.3.1.RELEASE. Upgrading either during an infrastructure-focused assignment could introduce unrelated compatibility problems.

**Decision:** Build and run the applications with Java 11-compatible images. Do not upgrade Spring Boot simply to use newer secret-loading features.

**Rationale:** Preserve compatibility and keep infrastructure changes focused and testable.

**Trade-off / future improvement:** Spring Boot 2.3.1 is no longer supported. A production modernization effort should plan a supported Spring Boot/JDK upgrade with regression testing. Spring Boot 2.3 does not support the `configtree:` import introduced in 2.4; external properties files are used instead (D-006).

## D-003 — Retain Maven `SNAPSHOT` versions for the assignment

**Status:** Accepted.

**Context:** The supplied Maven modules use `SNAPSHOT` artifact versions and are still being developed together.

**Decision:** Keep the existing `SNAPSHOT` versions rather than changing the parent, shared module, producer, and consumer version references during build-baseline and containerization work.

**Rationale:** Avoids unrelated POM changes and preserves the existing multi-module build.

**Trade-off:** A `SNAPSHOT` coordinate can refer to changing artifact contents; it is not an appropriate release identifier by itself.

**Future improvement:** Introduce immutable release versions, unique container-image tags/digests, and traceability between Git commits, Maven artifacts and released images through CI/CD.

## D-004 — Use separate multi-stage Dockerfiles with non-root runtimes

**Status:** Accepted — local containerization approach.

**Context:** The producer serves an HTTP API; the consumer processes bookings received through RabbitMQ. Both depend on the shared Maven module.

**Decision:** Maintain separate Dockerfiles for `booking-producer-service` and `booking-consumer-service`. Each uses a Maven/Java 11 build stage and a Java 11 runtime stage, copying only the executable application JAR into the final image. Build from the repository root with Maven reactor options `-pl <service> -am` so `booking-contract` is included. Run the application as UID/GID `10001:10001`.

**Rationale:** Separates independently deployed workloads, omits build tooling from runtime images, and avoids running the application as root. Tests run as a distinct CI step; skipping them during image packaging does not replace CI testing.

**Trade-offs:** Build caching is not fully optimized, and version-tagged base images are not digest-pinned (D-013). Non-root execution requires explicit write permissions wherever application data is stored (D-008).

**Future improvement:** Copy POM files and resolve dependencies before copying source to improve repeat-build caching; consider further image hardening and vulnerability scanning.

## D-005 — Use Docker Compose locally; target GKE Autopilot

**Status:** Accepted — Compose is the local deployment mechanism; GKE is the **proposed** cloud target.

**Context:** The application comprises the booking producer, booking consumer, and RabbitMQ. The assignment permits Cloud Run or GKE.

**Decision:** Use Docker Compose for local development and integration testing. Target GKE Autopilot for the cloud deployment, with the booking producer, booking consumer, and RabbitMQ on the same cluster. Plan to run RabbitMQ as a single-replica StatefulSet with a PersistentVolumeClaim for broker storage and an internal Kubernetes Service for client connections. Use Kompose to generate initial manifests, then review and refine them for GKE Autopilot.

**Rationale:** GKE Autopilot gives the HTTP producer, the long-running consumer, and the stateful broker a common deployment environment while Google manages the worker nodes. Hosting RabbitMQ on-cluster gives both services a stable internal endpoint and keeps the broker private. A single broker replica is a manageable starting point for the assignment. The trade-off is that the team remains responsible for broker upgrades, monitoring, backups, and recovery, and a single replica provides no high availability.

**Trade-offs and deployment considerations:**

- Kompose does not translate every Compose feature or dependency guarantee directly into Kubernetes.
- Review Deployments/Services, startup and readiness probes, resource requests, networking, ConfigMaps, Secrets and storage before any cloud deployment.
- An H2 volume is **not** a production database architecture, especially if consumers are scaled horizontally (D-007).
- GKE introduces cloud cost and operational complexity compared with local Compose. Deployment to GKE Autopilot remains unverified.

**Implementation approach:** Validate Dockerfiles and Compose locally; generate manifests with Kompose; refine them for Autopilot; document the deployment process. The assignment's CI scope does **not** include executing a GKE deployment (D-011).

**Future improvement:** Kompose v1.21.0 (installed via Snap) failed to convert `compose.yaml`. Retry the conversion with a newer Kompose release. If it succeeds, review and refine the generated manifests for GKE Autopilot.

## D-006 — Externalize runtime configuration and credentials

**Status:** Accepted — local configuration pattern.

**Context:** RabbitMQ connection details and database settings must differ by environment and must not be hardcoded in Dockerfiles or packaged JARs.

**Decision:** Supply non-sensitive settings (for example, RabbitMQ host/port and datasource URL) through Docker Compose configuration/environment variables. Supply sensitive values through file-backed Compose secrets, mounted for only the services that need them. Use Spring Boot 2.3's external-properties loading mechanism (for example, `SPRING_CONFIG_ADDITIONAL_LOCATION`) to read mounted `*.properties` files. Exclude real secret files from Git and Docker build contexts.

**Rationale:** Separates application artifacts from environment-specific settings, reduces accidental credential exposure and avoids rebuilding images to change runtime configuration.

**Operational consequence:** Recreate affected containers to pick up changed runtime configuration or file-backed secret contents, without rebuilding unchanged images. The procedure belongs in `README.md`; container recreation does not include source-code changes. Recreating the consumer must not remove its named H2 volume.

**Limitations:** Compose file-backed secrets are not an encrypted secret manager; host-side file permissions still matter. Secrets are not automatically mapped to Spring Boot environment variables; external file loading must be configured explicitly. Broker credential rotation can require updating the RabbitMQ broker's own user configuration, not merely restarting clients.

**Cloud consideration:** Use appropriately scoped Google Secret Manager resources and workload identities/IAM. Treat RabbitMQ and database passwords as separately managed secrets, and avoid placing real secret values in Terraform state.

## D-007 — Persist H2 locally and propose MongoDB Atlas for production

**Status:** Accepted for local development; **production migration proposed and deferred**.

**Context:** The original consumer used in-memory H2, which loses booking data on application restart. The assignment identifies MongoDB Atlas on Google Cloud as the organization's production datastore.

**Decision:** Continue to use H2 for the local Compose environment, configured as a file-based database (for example, `jdbc:h2:file:/data/ecabs`) on a Docker named volume such as `booking_data`. Propose MongoDB Atlas for a real GKE production deployment instead of treating embedded H2 as production-ready.

**Rationale:** Preserves compatibility with the supplied Java application, avoids a database migration within the challenge, and enables local persistence across container restarts and recreation while aligning the proposed production architecture with the stated datastore platform.

**Trade-offs:** File-backed H2 does not provide managed backups, high availability or independent horizontal database scaling. A named volume preserves data only while it is retained; `docker compose down -v` removes it. Migrating from relational H2/JPA persistence to MongoDB is **not** a datasource-URL change: domain mappings, repositories, queries, transaction semantics and tests require review.

**Future improvement:** Refactor persistence for MongoDB Atlas, plan data migration, run integration tests, establish secure credentials/private connectivity and define backup/recovery procedures. Do not claim MongoDB integration has been implemented.

## D-008 — Initialize H2 volume permissions with BusyBox

**Status:** Accepted — local Compose design.

**Context:** The consumer runs as non-root (`10001:10001`), but file-backed H2 must write to its persistent volume.

**Decision:** Use a short-lived BusyBox initialization service that temporarily runs as root and assigns the volume's ownership to `10001:10001` when the configured datasource uses file-backed H2. Configure the consumer's Compose dependency with `condition: service_completed_successfully`, so permission initialization finishes before consumer startup.

**Rationale:** Keeps the application container non-root, removes manual volume-fixing steps and supports both file-backed and in-memory H2 configurations.

**Trade-offs:** Adds a one-off container and startup dependency; the initialization process requires temporary root privileges. Recursive ownership changes may become expensive on large volumes. In-memory mode does not require the permission change, although the Compose initialization service may still be defined.

**Cloud consideration:** This is a Compose-specific solution. If any file-backed storage is used on Kubernetes, review volume ownership/security context and Autopilot-compatible init-container options; a production database service is preferable for booking data (D-007).

## D-009 — Rely on GKE Autopilot's managed container runtime, not VM startup scripts

**Status:** Accepted — cloud architecture decision, not a deployed implementation.

**Context:** Direct deployments to AWS EC2 or Google Compute Engine may use initialization scripts (`user_data` or `metadata_startup_script`) to install a container runtime and dependencies. This project targets managed Kubernetes.

**Decision:** Do not provision bespoke application VMs or install Docker Engine via startup scripts. Build OCI-compatible producer and consumer images, store them in Google Artifact Registry, and reference them from Kubernetes manifests. Rely on GKE Autopilot to manage nodes and the `containerd` runtime.

**Rationale:** Reduces host administration, supports standard container images and keeps application deployment distinct from node lifecycle management.

**Trade-offs:** Less node-level control and dependence on Autopilot workload/security constraints. The application team still owns workload security, configuration, scaling, observability and reliability. Terraform can also manage Kubernetes resources, but that is not the chosen initial division of responsibility.

**Future consideration:** Reassess GKE Standard or Compute Engine if specialized OS or VM-level access becomes a justified requirement.

## D-010 — Manage GCP infrastructure with Terraform and workloads with manifests

**Status:** Accepted — Terraform design selected; plan/validation results require repository verification; no live apply claimed.

**Context:** The assignment requests Terraform for artifact storage, runtime, messaging, IAM/service accounts and secret management, using placeholder GCP project information. Infrastructure code is to be reviewed with `terraform validate` and `terraform plan`, not applied by the reviewers.

**Decision:** Use Terraform to describe the GCP footprint (including Artifact Registry, GKE Autopilot, IAM/service accounts and Secret Manager resources as applicable), while Kubernetes manifests describe producer/consumer/RabbitMQ workloads and their runtime configuration.

**Rationale:** Makes infrastructure reviewable and repeatable without requiring live cloud deployment, and keeps the initial responsibilities of Terraform and Kubernetes manifests understandable.

**Limitations:** Terraform validation does not prove cloud resources exist or that application workloads can run successfully. Secret Manager resource containers can be declared in Terraform without writing actual password versions into Terraform state; secret contents and workload access must be handled separately.

**Future improvement:** Add authenticated plan/deploy stages and stronger policy/security validation once a real GCP environment and an approved deployment workflow exist.

## D-011 — Keep CI focused on build, tests and image validation

**Status:** Accepted — pipeline scope.

**Context:** A useful minimum CI pipeline should catch Java test regressions and container packaging problems without needing live GCP access.

**Decision:** In GitHub Actions, build and test the Maven modules, validate Compose syntax with `docker compose config -q`, and build container images using `docker compose build`. Document the expected GKE deployment-on-merge workflow, but do not execute a cloud deployment as part of this challenge.

**Rationale:** Prioritizes reproducibility, automated tests and container build validation within assignment scope.

**Trade-off:** A successful build does not establish runtime health or end-to-end message delivery. A small runtime smoke test addresses part of this gap (D-012), while full RabbitMQ/H2 integration tests remain deferred.

**Future improvement:** Add infrastructure checks such as `terraform fmt -check` and `terraform validate` where credentials and initialization requirements allow, and later publish versioned images/deploy to GKE with appropriate approvals.

## D-012 — Add a Docker Compose smoke test to CI

**Status:** Accepted — lightweight runtime validation scope.

**Context:** Even when Maven tests and Docker image builds succeed, the producer application may not start or respond to HTTP requests in the composed environment.

**Decision:** Extend CI to generate disposable runtime credentials, start the Compose stack, wait for the producer API with bounded retries, submit a representative booking POST using `ci/smoke-booking.json`, and assert the expected HTTP response/status. On failure, capture container logs; always clean up containers and temporary volumes afterwards.

**Rationale:** Exercises basic application startup, network access and runtime configuration/secrets without adding another test framework.

**Trade-offs:** API acceptance does **not** prove that RabbitMQ delivered the message, that the consumer saved it, or that H2 survives a restart. GitHub-hosted runners also do not represent GKE production conditions.

**Future improvement:** Test the full producer → RabbitMQ → consumer → database path, including persistence across container restarts, retry/error handling and recovery behaviour.

## D-013 — Defer Docker image SHA-256 digest pinning

**Status:** Accepted — hardening deferred.

**Context:** Docker Compose uses explicitly versioned public images (including RabbitMQ and BusyBox), and Dockerfile base images are referenced by tags. Tags are mutable, including explicitly versioned tags.

**Decision:** Keep the selected version tags for this assignment rather than pinning all base and dependency images to immutable digests.

**Rationale:** Limits maintenance overhead while focusing on Terraform, automated testing and submission documentation. Version tags express the intended version more clearly than `latest`, but they are not immutable.

**Trade-off:** Different pulls of a tag can resolve to different image contents, affecting reproducibility.

**Future improvement:** Pin tested images to SHA-256 digests, periodically review upstream security updates, scan for known vulnerabilities, refresh digests and validate updates through CI. Digest pinning improves reproducibility; it is not, by itself, a security-vulnerability fix.

## D-014 — Keep `booking-contract` within the Maven reactor; defer a private Maven repository

**Status:** Accepted — separate artifact repository deferred.

**Context:** The producer and consumer use the shared `booking-contract` module in the same Maven multi-module repository.

**Decision:** Continue building shared dependencies with the Maven reactor (`-pl` and `-am`) rather than publishing the module independently at this stage.

**Rationale:** The current build already resolves the shared module; publishing it separately would add authentication, access-control, versioning and CI/CD maintenance without a clear immediate benefit.

**Future improvement:** If `booking-contract` acquires independent release cycles or is reused across separate projects, publish stable versions to a private Maven repository in Google Artifact Registry. This is distinct from the Artifact Registry **Docker** repository used to distribute application container images.

## D-015 — Defer Static Analysis and Linting in CI

**Status:** Accepted — Deferred improvement.

**Context:** The GitHub Actions pipeline currently performs Maven builds and tests, Docker image builds, and a Docker Compose smoke test. Dedicated static analysis and linting tools are not integrated.

**Decision:** Defer additional linting and static analysis to a future CI enhancement.

**Rationale:** Prioritize functional validation, infrastructure-as-code and the assignment's core deliverables over introducing additional tooling and resolving potentially non-critical findings in the legacy codebase.

**Trade-offs:** The pipeline may not detect certain Dockerfile best-practice violations, Terraform configuration issues, YAML formatting problems or GitHub Actions workflow errors.

**Future Improvement:** Introduce Hadolint for Dockerfiles, TFLint for Terraform, actionlint for GitHub Actions workflows and optionally yamllint for YAML files. Evaluate findings locally before enforcing lint checks as mandatory CI quality gates.

---

**Scope boundary:** The assignment's local build/Compose environment is not presented as a production-grade, highly available system. MongoDB Atlas migration, full containerized end-to-end testing, digest pinning, independent Maven artifacts and actual cloud deployment are explicitly deferred or proposed above.
