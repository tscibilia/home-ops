## Migrating Jellyseerr PVC to Seerr

For future me: Steps to migrate the existing **Jellyseerr** persistent volume to the new **Seerr** deployment:

1. **Rename** the project and all related YAML files/references from `jellyseerr` to `seerr`.
2. **Commit and push** the changes so Flux can create the new Seerr deployment.
3. **Suspend** the Seerr HelmRelease in Flux:

   ```sh
   flux suspend hr seerr -n media
   ```
4. **Scale down** the Seerr deployment:

   ```sh
   kubectl scale deploy seerr -n media --replicas=0
   ```
5. **Apply the Volsync migration manifest** to copy data from the Jellyseerr PVC:

   ```sh
   kubectl apply -f migration.yaml
   ```
6. **Monitor** the `ReplicationDestination` until the migration completes:

   ```sh
   kubectl get replicationdestination seerr-restore -n media -w
   ```
7. **Remove** the migration resources once finished:

   ```sh
   kubectl delete -f migration.yaml
   ```
8. **Scale Seerr back up** and **resume** the HelmRelease:

   ```sh
   kubectl scale deploy seerr -n media --replicas=1
   flux resume hr seerr -n media
   ```

---

### migration.yaml example
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: jellyseerr-volsync-secret
  namespace: media
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: akeyless-secret-store
  target:
    name: jellyseerr-volsync-secret
    template:
      data:
        RESTIC_REPOSITORY: "/repository/jellyseerr"
        RESTIC_PASSWORD: "{{ .RESTIC_PASSWORD }}"
  dataFrom:
    - extract:
        key: /aws-creds
---
apiVersion: volsync.backube/v1alpha1
kind: ReplicationDestination
metadata:
  name: seerr-restore
  namespace: media
spec:
  trigger:
    manual: restore-once
  restic:
    repository: jellyseerr-volsync-secret
    destinationPVC: seerr
    copyMethod: Direct
    cacheStorageClassName: openebs-hostpath
    cacheAccessModes:
      - ReadWriteOnce
    cacheCapacity: 1Gi
    moverSecurityContext:
      runAsUser: 1000
      runAsGroup: 100
      fsGroup: 100
    enableFileDeletion: true
    cleanupCachePVC: true
    cleanupTempPVC: true
```