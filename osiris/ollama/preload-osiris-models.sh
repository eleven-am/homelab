#!/bin/sh
set -eu

OLLAMA_URL=http://127.0.0.1:11434
GEMMA_URL=http://127.0.0.1:8000/health

for _ in $(seq 1 120); do
  if curl -fsS "$GEMMA_URL" >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

curl -fsS "$GEMMA_URL" >/dev/null

ensure_model() {
  model="$1"
  if ! curl -fsS "$OLLAMA_URL/api/show" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"$model\"}" \
    >/dev/null 2>&1; then
    curl -fsS "$OLLAMA_URL/api/pull" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$model\",\"stream\":false}" \
      >/dev/null
  fi
}

ensure_model "gemma4:e4b"
ensure_model "bge-m3:latest"

curl -fsS "$OLLAMA_URL/api/generate" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gemma4:e4b","prompt":"Reply with OK.","stream":false,"keep_alive":"87600h","options":{"num_ctx":4096,"num_predict":1}}' \
  >/dev/null

curl -fsS "$OLLAMA_URL/api/embed" \
  -H 'Content-Type: application/json' \
  -d '{"model":"bge-m3:latest","input":"warmup"}' \
  >/dev/null
