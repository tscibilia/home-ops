## Migrate Plex VM to K8s

### Manually is the way to go...
After several failed automated attempts via an initContainer, I decided to manually run the migration in a separate pod but I needed access to the `plex` pvc. So I started the plex deployment and scaled it back to 0 (temporarily) so the pod would release the claim.

1. shutdown plex vm
2. tarball the plex directory
```bash
tar -czf /mnt/Media/library/plex/migrate/Plex.tar.gz -C "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server" .
```
3. init plex deployment
4. scale back plex deployment to 0 (see step 9 if using keda)
5. spin up temp migration pod with plex pvc and nfs volumeMounts
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: plex-migrate
  namespace: media
spec:
  restartPolicy: Never
  containers:
  - name: migrate-wait
    image: alpine:3.20
    command: ["sh", "-c", "tail -f /dev/null"]
    volumeMounts:
    - name: plex
      mountPath: /config
    - name: nfs
      mountPath: /media
  volumes:
  - name: plex
    persistentVolumeClaim:
      claimName: plex
  - name: nfs
    nfs:
      server: "nas.internal"
      path: /volume1/Media
```
6. exec into that pod `kubectl exec -it -n media plex-migrate -- sh`; and run the following commands:
```bash
rm -rf "/config/Library/Application Support/Plex Media Server/*"

tar --exclude='Cache/*' --exclude='Thumbnails/*' -xvzf "/media/library/plex/migrate/Plex.tar.gz" -C "/config/Library/Application Support/Plex Media Server/"

chown -R 1044:100 "/config/Library/Application Support/Plex Media Server"
```
7. evict the migration pod
8. scale plex deployment to 1
9. (optionally) add keda back to the kustomization file and reconcile. This was omitted originally because keda would automatically scale back up the deployment to 1 even though I set it to 0.