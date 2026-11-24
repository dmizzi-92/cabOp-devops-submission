#!/usr/bin/env bash
# Run at the root of the eCabs repository, alongside compose.yaml.
set -euo pipefail

for required in openssl; do
  command -v "$required" >/dev/null || { echo "Missing dependency: $required" >&2; exit 1; }
done

if [[ -e secrets/rabbitmq.conf || -e secrets/producer.properties || -e secrets/consumer.properties ]]; then
  echo 'Refusing to overwrite existing secrets. Back them up before regenerating.' >&2
  exit 1
fi

umask 077
mkdir -p secrets
chmod 700 secrets

rabbitmq_password="$(openssl rand -hex 24)"
h2_password="$(openssl rand -hex 24)"

printf 'default_user = booking_user\ndefault_pass = %s\n' "$rabbitmq_password" > secrets/rabbitmq.conf
printf 'spring.rabbitmq.password=%s\n' "$rabbitmq_password" > secrets/producer.properties
printf 'spring.rabbitmq.password=%s\nspring.datasource.password=%s\n' \
  "$rabbitmq_password" "$h2_password" > secrets/consumer.properties

# Compose file-backed secrets are bind-mounted. The Java containers run as
# uid 10001, and RabbitMQ runs as an unprivileged user; allow file reads.
# Host access remains restricted by the directory's 0700 permissions.
chmod 0444 secrets/rabbitmq.conf secrets/producer.properties secrets/consumer.properties

echo 'Created three secret files in ./secrets/ (contents not displayed).'
echo 'Ensure secrets/ is excluded from Git and Docker build contexts.'
