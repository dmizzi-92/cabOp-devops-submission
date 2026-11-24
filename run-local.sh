#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ ! -e secrets/rabbitmq.conf &&
      ! -e secrets/producer.properties &&
      ! -e secrets/consumer.properties ]]; then
  bash ./setup-secrets.sh
fi

for file in secrets/rabbitmq.conf secrets/producer.properties secrets/consumer.properties; do
  if [[ ! -s "$file" ]]; then
    printf 'Missing or empty local secret file: %s\n' "$file" >&2
    exit 1
  fi
done

case "${1:-}" in
  rebuild)
    exec docker compose up --build -d
    ;;
  "")
    if docker image inspect \
      ecabs-booking-producer:local \
      ecabs-booking-consumer:local >/dev/null 2>&1; then
      exec docker compose up --no-build -d
    fi
    exec docker compose up --build -d
    ;;
  *)
    printf 'Usage: bash run-local.sh [rebuild]\n' >&2
    exit 2
    ;;
esac