#!/bin/sh
set -eu

OLLAMA_URL=http://127.0.0.1:11434
GEMMA_URL=http://127.0.0.1:8000/health
MODEL=gpt-oss:20b

for _ in $(seq 1 120); do
  if curl -fsS "$GEMMA_URL" >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

curl -fsS "$GEMMA_URL" >/dev/null

if ! ollama show "$MODEL" >/dev/null 2>&1; then
  ollama pull "$MODEL"
fi

curl -fsS "$OLLAMA_URL/api/generate" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-oss:20b","prompt":"Reply with OK.","stream":false,"options":{"num_ctx":4096,"num_predict":1}}' \
  >/dev/null
