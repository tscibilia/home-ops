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