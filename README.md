# cabOp-devops submission

## Prerequisites

The project was developed and tested using the following tools and versions:

| Tool | Version |
|---|---|
| **Java (OpenJDK)** | 11.0.33 |
| **Apache Maven** | 3.6.3 |
| **Docker Engine** | 29.1.3 |
| **Docker Compose** | 1.29.2 |
| **Git** | 2.34.1 |
| **Terraform** | 1.15.8 |
| **Google Cloud SDK (gcloud)** | 594.0.0 |
| **OpenSSL** | 3.0.2 |

**Development environment:**
- **OS:** Ubuntu 22.04 (WSL2)
- **Architecture:** linux/amd64
- **Java runtime:** OpenJDK 11

**Notes:**
- Java 11 and Maven are required for building the Spring Boot services locally.
- Docker and Docker Compose are required to run the containerized application.
- OpenSSL is used by the optional `setup-secrets.sh` script to generate credentials.
- Terraform and Google Cloud SDK are intended for infrastructure validation and cloud-related operations; they are not required for local execution.
- The versions listed above represent the development environment. Other compatible versions may work but have not been explicitly verified.

## Run locally

Install Bash and Docker with the Compose v2 plugin. The first run also
requires OpenSSL if you use automatic credential setup.

From the repository root, run:

```bash
bash run-local.sh
```

On a fresh clone, `run-local.sh` calls `setup-secrets.sh` to generate local
credentials, builds the producer and consumer images if either is missing,
and starts the stack in the background. Later runs reuse the existing
credentials and images.

After changing application code or a Dockerfile, rebuild the images and
start the stack with:

```bash
bash run-local.sh rebuild
```

### Endpoint
http://localhost:8080/swagger-ui/index.html?configUrl=/v3/api-docs/swagger-config

### Local credentials

`setup-secrets.sh` generates one RabbitMQ password shared by the broker,
producer, and consumer, plus a separate H2 password for the consumer.
It creates these files under `secrets/`:

| File | Contents (one setting per line) |
| --- | --- |
| `secrets/rabbitmq.conf` | `default_user = booking_user`<br>`default_pass = YOUR_RABBITMQ_PASSWORD` |
| `secrets/producer.properties` | `spring.rabbitmq.password=YOUR_RABBITMQ_PASSWORD` |
| `secrets/consumer.properties` | `spring.rabbitmq.password=YOUR_RABBITMQ_PASSWORD`<br>`spring.datasource.password=YOUR_H2_PASSWORD` |

`run-local.sh` calls the setup script only when all three files are absent.
To generate the credentials separately, run `bash setup-secrets.sh` from
the repository root. The script refuses to overwrite existing files.

If you prefer to supply your own credentials, follow the manual setup
instructions above. Once all three populated files are in place,
`bash run-local.sh` starts the stack without using OpenSSL. Keep the
populated files out of Git and the Docker build contexts.

## Part 1 — Ship it

### Runtime - GKE Autopilot (See DECISIONS.md)

The [DECISIONS.md](./DECISIONS.md) file documents the key technical and architectural decisions made throughout this assignment, including their rationale, trade-offs, limitations and future improvements.

It covers containerization, local orchestration, database persistence, security, CI/CD and the proposed GKE Autopilot deployment architecture.

Decisions distinguish between implemented functionality, proposed architecture and deliberately deferred enhancements.

### Infrastructure as Code (Terraform)

The `terraform/` directory defines the proposed Google Cloud infrastructure for the eCabs booking system, including:

- **Artifact Registry** — Stores producer and consumer Docker images.
- **VPC Networking** — Dedicated VPC, subnet and secondary IP ranges for GKE.
- **GKE Autopilot** — Managed Kubernetes runtime for the application workloads.
- **IAM** — Service accounts and least-privilege access permissions.
- **Secret Manager** — Secure management of RabbitMQ and database credentials.
- **Outputs** — Exposes useful cluster and Artifact Registry information.

#### Terraform Validation

See [README.md](./terraform/README.md)

### Continuous Integration (CI)

The project uses **GitHub Actions** (`.github/workflows/ci.yaml`) to automate build, test and runtime validation. The pipeline runs on pushes and merges to `main`, pull requests targeting `main`, and manual triggers.

The pipeline performs the following steps:

1. **Build and test:** Compiles all Maven modules and executes automated tests using Java 11.
2. **Docker build:** Builds the producer and consumer images using Docker Compose.
3. **Secrets:** Generates temporary credentials for CI without storing sensitive information in GitHub.
4. **Smoke test:** Starts the Docker Compose stack, waits for the producer API and submits a sample booking POST request using `ci/smoke-booking.json`.
5. **Cleanup:** Collects container logs on failure and removes containers and temporary volumes after execution.

**Deployment:** GKE Autopilot is the proposed cloud runtime. Actual cloud deployment is not performed as part of this assignment. The CI pipeline validates the application locally on a GitHub-hosted runner.

Pipeline execution results and logs are available under the repository's **Actions** tab.



## Part 2 — Fixes and Technical Findings

Issues identified during application review, containerization, and integration testing are documented in [FIXES.md](FIXES.md).

The document outlines identified risks, implemented fixes, verification steps, and outstanding improvements. It also distinguishes between issues resolved during the assignment and enhancements deferred for production.

## Part 3 — Surge Night Incident Response

The [SURGE.md](SURGE.md) document presents a hypothetical production incident involving a sudden spike in booking demand. It covers the potential failure chain, prioritised actions during the first 15 minutes, and proposed architectural, capacity, monitoring and operational improvements to improve reliability during future surges.

## Part 4 — Optional stretch: Database Migration ADR

[ADR.md](ADR.md) describes the proposed zero-downtime, zero-data-loss migration from file-backed H2 to MongoDB Atlas, including live replication, backfill, validation, cutover, and rollback.
