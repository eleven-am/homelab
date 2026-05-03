# Standalone Ada

This folder deploys Ada as its own local gRPC service, separate from the `io-platform`
HelmRelease.

## Shape

- Namespace: `ada`
- Public service: `ada-grpc` on port `50051`, type `LoadBalancer`
- Private backing services: Postgres, Redis, Neo4j, Qdrant, MinIO
- LLM route: in-cluster LiteLLM at `http://litellm-service.litellm.svc.cluster.local:4000/v1`
- Billing/quota: disabled by omission; `IO_BEAM_GRPC_ADDR` is intentionally not set

## Required Secret

Create a SOPS-encrypted `secret.yaml` in this folder before enabling the workload in Flux.
Use `secret.example.yaml` as the shape.

Required keys:

- `ADA_BEAM_GRPC_AUTH_TOKEN`
- `ADA_BEAM_LLM_API_KEY`
- `ADA_BEAM_LLM_EMBED_API_KEY`
- `POSTGRES_PASSWORD`
- `NEO4J_PASSWORD`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`

The `zot-pull-secret` image pull secret is expected to be reflected into the namespace by
the existing Reflector setup from the `zot` namespace.

## Backups

Ada writes document payloads to its own `ada-beam-payloads` bucket in the `ada-minio`
StatefulSet. Standalone backup CronJobs also write database snapshots into Ada-owned MinIO
buckets:

- `postgres-backups/ada/`
- `neo4j-backups/ada/`
- `qdrant-backups/ada/`

This keeps the standalone Ada stack isolated from the shared platform MinIO. Offsite backup
for this Ada-owned MinIO should be added separately if this becomes production data.

## Access

After reconciliation:

```sh
kubectl -n ada get svc ada-grpc
```

Use the assigned `EXTERNAL-IP` with Ada's gRPC clients on port `50051`.
