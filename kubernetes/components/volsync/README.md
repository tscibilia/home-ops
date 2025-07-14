# VolSync Template

## Flux Kustomization

This requires `postBuild` configured on the Flux Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app home-assistant
  namespace: flux-system
spec:
  ...
  postBuild:
    substitute:
      APP: *app
      VOLSYNC_CAPACITY: 1Gi
  ...
```

## Required `postBuild` vars:

- `APP`: The application name
- `VOLSYNC_CAPACITY`: The PVC size

## Optional `postBuild` vars:

- `VOLSYNC_CLAIM`: Alternate PVC instead of `APP`
- `VOLSYNC_PUID`: The value for runAsUser in the mover
- `VOLSYNC_PGID`: The value for runAsGroup and fsGroup in the mover

## Cache Volume
The cache significantly improves performance by avoiding downloading repository metadata repeatedly. The size of this cache volume can be controlled via `cacheCapacity` parameter.
```mermaid
flowchart TD
    subgraph Volumes
        Data["Data Volume<br/>(Source or Destination PVC)"]
        Cache["Cache Volume<br/>(Restic metadata)"]
    end

    Pod["Restic Job Pod"]

    Pod -- mounts --> Data
    Pod -- mounts --> Cache
```

## Backup process (ReplicationSource)
```mermaid
sequenceDiagram
    Note over VolSync Controller: ReplicationSource created/triggered
    VolSync Controller->>+Source PVC: Create Point-in-Time copy
    Source PVC->>+PiT Copy (Snapshot/Clone): Create Snapshot/Clone
    VolSync Controller->>+Restic Backup Job: Create Restic Backup Job
    Restic Backup Job-->>-PiT Copy (Snapshot/Clone): Mount PiT copy
    Restic Backup Job->>+Restic Repository: Check if repository exists
    Restic Repository-->>Restic Backup Job: Repository status
    alt Repository doesn't exist
        Restic Backup Job->>Restic Repository: Initialize repository (restic init)
    end
    Restic Backup Job->>+Restic Repository: Backup data (restic backup)
    Restic Repository-->>Restic Backup Job: Apply retention policy (restic forget)
    alt Pruning interval reached
        Restic Backup Job->>Restic Repository: Prune repository (restic prune)
    end
    Restic Backup Job-->>VolSync Controller: Backup completed
    VolSync Controller->>VolSync Controller: Schedule next backup
```

## Restore Process (ReplicationDestination)
```mermaid
sequenceDiagram
    Note over VolSync Controller: ReplicationDestination created/triggered
    alt PVC specified via destinationPVC
        VolSync Controller->>+Destination PVC: Use existing PVC
    else No destinationPVC
        VolSync Controller->>+Destination PVC: Provision new PVC
    end
    VolSync Controller->>+Restic Restore Job: Create Restic Restore Job
    Restic Restore Job->>+Restic Repository: Connect to repository
    Restic Restore Job->>+Restic Repository: Retrieve backup snapshots
    alt Specific snapshot requested
        Restic Restore Job->>+Restic Repository: Retrieve specific snapshot (previous/restoreAsOf)
    else
        Restic Restore Job->>+Restic Repository: Retrieve latest snapshot
    end
    Restic Restore Job->>-Destination PVC: Restore data
    Restic Restore Job-->>VolSync Controller: Update status
```