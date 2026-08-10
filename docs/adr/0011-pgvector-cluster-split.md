# Separate pgvector cluster for vector workloads

**Status:** accepted
**Date:** 2026-05-21
**Refines:** ADR-0004

Apps needing vector search (Immich, and later the AI-namespace services) were moved onto a second CloudNativePG cluster, `pgvector-cluster`, running with vectorchord — rather than adding the extension to the general `pgsql-cluster`.

## Consequences

- Two clusters to operate: `pgsql-cluster` for general apps, `pgvector-cluster` for vector workloads. Apps select via `CNPG_NAME` in `ks.yaml`.
- The extension's upgrade cadence is decoupled from the cluster every other app depends on — a vectorchord upgrade cannot take down general Postgres.
- Hard to reverse: merging the clusters later means a data migration, which is why this is recorded rather than left as configuration.
