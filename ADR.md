## Stage 1 — Enable live replication.

Assuming the current H2 db is no longer on memory but is now file-based to establish an improved migration baseline, we will migrate booking data to MongoDB Atlas while continuing to process bookings. H2 will remain the source of truth during the backfill. Before the backfill starts, the consumer will begin saving each new booking and a pending Atlas write in the same H2 transaction, acknowledging the RabbitMQ message only after that transaction commits. This lets the consumer continue processing bookings if Atlas is temporarily unavailable. A background worker will deliver pending writes to Atlas and mark them as delivered only after Atlas confirms the write. The stable booking ID will be unique in H2 and used as the MongoDB document’s _id, so RabbitMQ redelivery and Atlas upsert retries can be handled without creating duplicate bookings.

## Stage 2 — Backfill and validate

With H2 still authoritative, backfill historical bookings while live replication continues. Both paths upsert into Atlas using the stable booking ID as _id, so overlap and retries are safe for immutable bookings. Validate a fixed set of H2 records by comparing each booking’s ID and business fields against Atlas. Repair missing or mismatched documents from H2 and rerun validation. Track live replication lag separately. Proceed to cutover only once the historical set reconciles with zero missing or mismatched bookings.

## Stage 3 — Verify and cut over to Atlas

While H2 remains authoritative, compare bookings in H2 and Atlas by ID and business fields. Use shadow reads if there is a live booking read path. Otherwise, compare the stored records directly. Repair discrepancies from H2 and rerun the checks. At cutover, keep the booking API accepting requests into RabbitMQ while the H2 consumer finishes in-flight writes and stops taking new deliveries. Drain the outbox through that final H2 write boundary and verify that Atlas has caught up. Then start consuming queued bookings against Atlas as the new source of truth. The API stays available, with a brief processing delay during the handoff.


## Stage 4 — Retain H2 for rollback, then retire it

During the grace period, Atlas remains the source of truth. Record each new booking and a pending H2 replay entry in the same Atlas transaction, then acknowledge the RabbitMQ message after commit. If rollback is needed, keep the API accepting bookings into RabbitMQ while the Atlas consumer finishes its in-flight writes and stops taking new deliveries. Replay the outstanding entries into H2 using the stable booking ID, then verify all bookings through the final Atlas write are present and correct in H2 before resuming consumption against it. If the grace period ends without a rollback, retire H2 and remove the replay mechanism.