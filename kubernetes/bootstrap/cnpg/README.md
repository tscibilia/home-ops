# CNPG Clusters Bootstrap with Recovery

This directory contains a Kustomize overlay for bootstrapping CNPG PostgreSQL clusters with recovery from Barman backups.

**Clusters managed:**
- `pgsql-cluster` - Main PostgreSQL cluster
- `immich17` - Immich-specific cluster with vectorchord extension

## When to Use

**Use this when:**
- Rebuilding the cluster and you want to restore from backups
- Recovering from a disaster scenario
- Migrating to new hardware/cluster

**Don't use this when:**
- Creating a fresh database cluster (use normal Flux deployment)
- Cluster already exists and is healthy

## How It Works

This overlay:
1. References the base cluster config from `kubernetes/apps/database/cnpg/pgsql-cluster/app`
2. Adds the `bootstrap.recovery` section to restore from Barman backups
3. Restores from the **latest available backup** by default

## Usage

### Fresh Bootstrap (No Restore)

```bash
# Normal bootstrap - creates empty databases
just bootstrap default
```

### Bootstrap with Restore

```bash
# 1. Run normal bootstrap (installs CNPG operator)
just bootstrap default

# 2. Restore CNPG clusters from backup
just bootstrap cnpg

# 3. Verify clusters are healthy
kubectl get cluster -n database
```

### Restore to Specific Point in Time

If you need to restore to a specific backup (not latest):

1. Edit `kustomization.yaml` and add `recoveryTarget`:
   ```yaml
   - op: add
     path: /spec/bootstrap/recovery/recoveryTarget
     value:
       backupID: 20251208T035402
   ```

2. Run the restore:
   ```bash
   just bootstrap cnpg
   ```

3. Remove the `recoveryTarget` section after restore completes

## Important Notes

- **One-time operation**: The `bootstrap.recovery` block only matters during cluster creation
- **After restore**: Flux takes over and manages the cluster via GitOps
- **No manual cleanup needed**: The bootstrap config is separate from Flux config
- **Backup location**: Configured via the barman-cloud plugin (uses same bucket as running cluster)

## Directory Structure

```
bootstrap/
└── cnpg/                   # Bootstrap-specific config
    ├── kustomization.yaml  # Recovery overlay (both clusters)
    └── README.md           # This file

kubernetes/apps/database/cnpg/
├── pgsql-cluster/          # Main cluster (Flux GitOps)
├── immich17/               # Immich cluster (Flux GitOps)
└── ks.yaml                 # Flux Kustomization
```

## Troubleshooting

**Cluster stuck in "Bootstrapping" state:**
```bash
# Check CNPG operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg -f

# Check cluster events
kubectl describe cluster -n database pgsql-cluster
```

**Backup not found:**
- Verify backup exists in S3/Minio bucket
- Check barman plugin configuration in cluster.yaml
- Ensure bucket credentials are correct
