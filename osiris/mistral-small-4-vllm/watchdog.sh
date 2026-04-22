#!/bin/sh
set -eu

SERVICE_DIR=/home/royossai/services/mistral-small-4-vllm
CONTAINER=mistral-small-4-vllm
HEALTH_URL=http://127.0.0.1:8000/health
MIN_STARTUP_SECONDS=1200

status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTAINER" 2>/dev/null || true)"
started_at="$(docker inspect --format '{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null || true)"

if [ -n "$started_at" ] && [ "$started_at" != "0001-01-01T00:00:00Z" ]; then
  started_epoch="$(date -u -d "$started_at" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date -u +%s)"
  age_seconds=$((now_epoch - started_epoch))

  if [ "$age_seconds" -lt "$MIN_STARTUP_SECONDS" ]; then
    exit 0
  fi
fi

case "$status" in
  healthy|starting)
    exit 0
    ;;
esac

if curl -fsS "$HEALTH_URL" >/dev/null; then
  exit 0
fi

cd "$SERVICE_DIR"
exec /usr/bin/docker compose -f "$SERVICE_DIR/compose.yaml" restart "$CONTAINER"
