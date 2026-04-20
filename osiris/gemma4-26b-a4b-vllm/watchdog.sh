#!/bin/sh
set -eu

SERVICE_DIR=/home/royossai/services/gemma4-26b-a4b-vllm
CONTAINER=gemma4-26b-a4b-vllm
HEALTH_URL=http://127.0.0.1:8000/health

status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTAINER" 2>/dev/null || true)"

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
