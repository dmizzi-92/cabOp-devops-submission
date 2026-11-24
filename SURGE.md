# SURGE.md

## 1. What breaks first, and why? Walk through the failure chain you read from these numbers.

The initial pressure is the approximately **12-fold increase in booking requests**, from 1,800 to 21,400 requests per minute.

Assuming successful requests generate RabbitMQ messages, incoming work exceeds the consumer's observed processing throughput, which remains at 30 messages/second. This creates a processing bottleneck, with RabbitMQ accumulating a backlog of 143,000 messages and climbing.

The consumer also exhibits significant memory pressure, increasing from 480 MB to 3.6 GB, with three confirmed OOMKilled restarts. Possible causes include excessive message buffering, retained processing objects or slow database operations, although the metrics do not establish the underlying cause.

Meanwhile, the producer's p99 latency increases from 240 ms to 6.8 seconds, while HTTP errors rise to 8%, predominantly 502/504 responses. RabbitMQ resource pressure, publisher blocking or producer-side resource saturation could explain this deterioration, but queue depth alone does not establish causation.

**The clearest confirmed component failures are the consumer's OOMKilled restarts.** The likely broader failure chain involves a surge in demand, insufficient effective processing throughput, an accumulating message backlog and deteriorating service performance. The precise sequence and root causes require additional telemetry.

## 2. The First 15 Minutes: What do you actually do, in order? Include what you deliberately do not do at 23:05 on a Friday.

**23:05–23:08 — Initial response:** Verify the incident's scope, assess service health and critical metrics, including producer latency/errors, RabbitMQ queue health and consumer memory/restarts. Notify the incident-response team.

**23:08–23:11 — Focused investigation:** Investigate consumer memory growth, CPU/JVM metrics, RabbitMQ prefetch and acknowledgement rates, and database constraints to identify potential bottlenecks.

**23:11–23:17 — Controlled mitigation:** Prioritise restoring service without losing bookings. If excessive prefetch and outstanding deliveries contribute to memory pressure, consider reducing prefetch after verifying restart and message-redelivery risks. Monitor memory, throughput and queue growth.

**23:17–23:20 — Reassessment:** Evaluate mitigation effectiveness, communicate remaining customer impact and coordinate further recovery or escalation if the incident persists.

**Deliberately avoided:** Queue purging, indiscriminate scaling, unnecessary restarts and untested deployments that could risk booking integrity or worsen the incident.

## Make next Friday boring: What do you change afterwards — architecture, capacity, process — and roughly what does it cost?

### Architecture

I would move booking persistence to a suitable external database, allowing multiple consumer instances to share a consistent datastore, read and write data simultaneously, and support better horizontal scalability under high traffic.

This would also reduce the risks associated with relying on a local database file, including storage failures and concurrent access limitations. That being said, the external database would need to be appropriately provisioned and performance-tested to ensure it can handle the increased workload without becoming a new bottleneck.

I would also implement idempotent processing to ensure that processing the same booking event more than once does not produce unintended duplicate effects.

### Capacity Planning

Using the surge-night metrics, assuming a persistent external database, linear scaling and an accurate 30 msg/s baseline, I would scale the consumer replica count to accommodate the expected peak booking demand, with additional capacity headroom. The required replica count would be determined through load testing, ensuring that RabbitMQ and the shared database can sustain the increased throughput.

I would combine scheduled scaling with demand-based autoscaling. Scheduled scaling would provision additional consumer capacity ahead of predictable Friday-night booking surges, while demand-based autoscaling would respond to unexpected increases in workload.

This approach could improve availability and reduce unnecessary compute costs compared with permanently running at peak capacity.

However, scaling thresholds, minimum and maximum replicas, startup delays and downstream database capacity would also need to be validated through load testing.

### Cost

For illustrative purposes, assuming a cost of €0.05 per replica-hour, running 15 consumer replicas continuously would cost approximately €540 per month, compared with €82.40 per month using scheduled scaling.

However, these estimates assume the planned replica counts can handle the expected workload. In practice, downstream bottlenecks may limit throughput improvements, while factors such as cross-zone network traffic could introduce additional costs.

These estimates cover consumer compute only and exclude database, RabbitMQ, networking and monitoring expenses.

**N.B.** Actual GCP costs would depend on the allocated resources and applicable GKE charges.

### Process

I would perform spike testing by introducing sudden jumps in traffic, sustaining them for a period and then dropping traffic suddenly to validate autoscaling responsiveness, rate limiting and recovery from overload.

Regarding metrics, I would monitor customer-facing performance (HTTP error rate, p99 latency, request rate) and internal processing health, including CPU usage, service memory usage, database health and RabbitMQ queue depth. High memory consumption and growing RabbitMQ queue depth would trigger alerts based on defined thresholds.

I would prepare the on-call engineer by building a single dashboard focused on noteworthy service metrics, as well as a runbook outlining what actions to take based on those metrics. I would define clear triggers for mitigation actions and document rollback and recovery checks after applying fixes.