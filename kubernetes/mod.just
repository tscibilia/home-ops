set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
default:
    just -l kube

[doc('Browse a PVC')]
browse-pvc namespace claim:
    just check-tools kubectl
    kubectl browse-pvc -n {{ namespace }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Open a shell on a node')]
node-shell node:
    just check-tools kubectl
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    just check-tools kubectl
    for phase in Failed Pending Succeeded; do \
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just check-tools flux-local kubectl
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --field-manager=kustomize-controller -f /dev/stdin

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just check-tools flux-local kubectl
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

[doc('Sync GitRepositories')]
sync-git:
    just check-tools kubectl
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync OCIRepositories')]
sync-oci:
    just check-tools kubectl
    kubectl get ocirepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ocirepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync a single ExternalSecret')]
sync-es ns name:
    just check-tools kubectl
    kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite es "{{ name }}" force-sync="$(date +%s)"; \

[doc('Sync a single Flux HelmRelease')]
sync-hr ns name:
    just check-tools kubectl
    kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite hr "{{ name }}" reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"; \

[doc('Sync a single Flux Kustomization')]
sync-ks ns name:
    just check-tools kubectl
    kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite ks "{{ name }}" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \

[doc('Sync all ExternalSecrets')]
sync-all-es:
    just check-tools kubectl
    kubectl get es --no-headers -A | while read -r ns name _; do \
        just k8s sync-es "$ns" "$name"; \
    done

[doc('Sync all Flux HelmReleases')]
sync-all-hr:
    just check-tools kubectl
    kubectl get hr --no-headers -A | while read -r ns name _; do \
        just k8s sync-hr "$ns" "$name"; \
    done

[doc('Sync all Flux Kustomizations')]
sync-all-ks:
    just check-tools kubectl
    kubectl get ks --no-headers -A | while read -r ns name _; do \
        just k8s sync-ks "$ns" "$name"; \
    done

[doc('Restart all failed Flux Kustomizations')]
ks-restart:
    just check-tools kubectl flux
    kubectl get ks --all-namespaces | grep False | awk '{print $2, $1}' | while read -r name namespace; do \
        flux suspend kustomization "$name" -n "$namespace"; \
        flux resume kustomization "$name" -n "$namespace" & \
    done

[doc('Restart all failed Flux HelmReleases')]
hr-restart:
    just check-tools kubectl flux
    kubectl get hr --all-namespaces | grep False | awk '{print $2, $1}' | while read -r name namespace; do \
        flux suspend helmrelease "$name" -n "$namespace"; \
        flux resume helmrelease "$name" -n "$namespace" & \
    done

[doc('Force a single Kustomization to reconcile from Source')]
ks-reconcile ns name:
    just check-tools flux
    flux reconcile kustomization "{{ name }}" -n "{{ ns }}" --with-source

[doc('Force a single HelmRelease to reconcile from Source')]
hr-reconcile ns name:
    just check-tools flux
    flux reconcile helmrelease "{{ name }}" -n "{{ ns }}" --with-source

[doc('Force all Flux Kustomizations to reconcile from Source')]
ks-reconcile-all:
    just check-tools flux
    flux reconcile kustomization --namespace flux-system --with-source

[doc('Force all HelmReleases to reconcile from Source')]
hr-reconcile-all:
    just check-tools flux
    flux reconcile helmrelease --all --with-source

[doc('Suspend or resume a Keda ScaledObject')]
keda state ns name:
    just check-tools kubectl
    kubectl -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite so "{{ name }}" autoscaling.keda.sh/paused{{ if state != "suspend" { "-" } else { "=true" } }}

[doc('Suspend or resume all Keda ScaledObjects')]
keda-all state:
    just check-tools kubectl
    kubectl get scaledobjects --no-headers -A | while read -r ns name _; do \
        just kube keda "{{ state }}" "$ns" "$name"; \
    done

[doc('Snapshot a single VolSync PVC')]
snapshot ns name:
    just check-tools kubectl
    kubectl -n "{{ ns }}" patch replicationsources "{{ name }}" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'; \

[doc('Snapshot all VolSync PVCs')]
snapshot-all:
    just check-tools kubectl
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" patch replicationsources "$name" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'; \
    done

[doc('Suspend or resume VolSync')]
volsync state:
    just check-tools flux kubectl
    flux -n volsync-system {{ state }} kustomization volsync
    flux -n volsync-system {{ state }} helmrelease volsync
    kubectl -n volsync-system scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Unlock all VolSync restic source repos')]
volsync-unlock:
    just check-tools kubectl
    kubectl get replicationsources --all-namespaces --no-headers -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' | while IFS=',' read -r ns name; do \
        kubectl -n "$ns" patch --field-manager=flux-client-side-apply replicationsources "$name" --type merge -p "{\"spec\":{\"restic\":{\"unlock\":\"$(date +%s)\"}}}"; \
    done

[doc('List VolSync snapshots for an application')]
volsync-list ns name:
    just check-tools kubectl envsubst
    @echo "Listing snapshots for {{ name }} in {{ ns }} namespace..."
    @export NS="{{ ns }}" APP="{{ name }}" && \
        envsubst < {{ kubernetes_dir }}/components/volsync/resources/list.yaml.j2 | kubectl apply -f -
    @kubectl -n {{ ns }} wait job/{{ name }}-list-snapshots --for=condition=complete --timeout=5m
    @kubectl -n {{ ns }} logs job/{{ name }}-list-snapshots
    @kubectl -n {{ ns }} delete job {{ name }}-list-snapshots

[doc('Restore VolSync backup for an application')]
volsync-restore ns name previous:
    just check-tools kubectl flux envsubst jq
    @echo "Starting restore for {{ name }} in {{ ns }} namespace from snapshot {{ previous }}..."
    @if kubectl -n {{ ns }} get scaledobject {{ name }} &>/dev/null; then \
        echo "Pausing KEDA ScaledObject..."; \
        just kube keda suspend "{{ ns }}" "{{ name }}"; \
    fi
    @echo "Suspending Flux & scaling down application..."
    just kube flux-suspend "{{ ns }}" "{{ name }}"
    just kube app-scale-down "{{ ns }}" "{{ name }}"
    @echo "Creating ReplicationDestination for restore..."
    @eval $(kubectl -n {{ ns }} get replicationsources/{{ name }} -o json | jq -r '"export CLAIM=\(.spec.sourcePVC) STORAGE_CLASS=\(.spec.restic.storageClassName) ACCESS_MODES=\(.spec.restic.accessModes[0]) PUID=\(.spec.restic.moverSecurityContext.runAsUser) PGID=\(.spec.restic.moverSecurityContext.runAsGroup)"') && \
        export NS="{{ ns }}" APP="{{ name }}" PREVIOUS="{{ previous }}" && \
        envsubst < {{ kubernetes_dir }}/components/volsync/resources/replicationdestination.yaml.j2 | kubectl apply -f -
    @echo "Waiting for completion and cleaning up..."
    @kubectl -n {{ ns }} wait job/volsync-dst-{{ name }}-manual --for=condition=complete --timeout=120m
    @kubectl -n {{ ns }} delete replicationdestination {{ name }}-manual
    @echo "Resuming Flux resources & wating for 'ready' pod status..."
    just kube flux-resume "{{ ns }}" "{{ name }}"
    @kubectl -n {{ ns }} wait pod --for=condition=ready --selector="app.kubernetes.io/name={{ name }}" --timeout=5m || true
    @if kubectl -n {{ ns }} get scaledobject {{ name }} &>/dev/null; then \
        echo "Resuming KEDA ScaledObject..."; \
        just kube keda resume "{{ ns }}" "{{ name }}"; \
    fi
    @echo "Restore complete!"

[doc('View a secret')]
view-secret namespace secret:
    just check-tools kubectl
    kubectl view-secret -n {{ namespace }} {{ secret }}

[doc('Restart network stack in dependency order')]
restart-network:
    just check-tools kubectl
    just log info "Restarting CoreDNS..."
    kubectl rollout restart deployment/coredns -n kube-system
    kubectl rollout status deployment/coredns -n kube-system --timeout=120s
    just log info "Restarting Cilium..."
    kubectl rollout restart daemonset/cilium -n kube-system
    kubectl rollout restart deployment/cilium-operator -n kube-system
    kubectl rollout status daemonset/cilium -n kube-system --timeout=180s
    kubectl rollout status deployment/cilium-operator -n kube-system --timeout=60s
    just log info "Restarting Cloudflared..."
    kubectl rollout restart deployment/cloudflared -n network
    kubectl rollout status deployment/cloudflared -n network --timeout=120s
    just log info "Restarting External-DNS..."
    kubectl rollout restart deployment/external-dns -n network
    kubectl rollout status deployment/external-dns -n network --timeout=120s
    just log info "Restarting k8s-gateway..."
    kubectl rollout restart deployment/k8s-gateway -n network
    kubectl rollout status deployment/k8s-gateway -n network --timeout=120s
    just log info "Restarting Envoy-Gateway..."
    kubectl rollout restart deployment/envoy-gateway -n network
    kubectl rollout status deployment/envoy-gateway -n network --timeout=120s
    just log info "Restarting Envoy gateways..."
    kubectl rollout restart deployment/envoy-internal deployment/envoy-external -n network
    kubectl rollout status deployment/envoy-internal -n network --timeout=120s
    kubectl rollout status deployment/envoy-external -n network --timeout=120s
    just log info "Network stack restart complete"

[private]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"

[private]
[doc('Suspend Flux resources for an app')]
flux-suspend ns name:
    @flux suspend kustomization {{ name }} -n {{ ns }}
    @flux suspend helmrelease {{ name }} -n {{ ns }}

[private]
[doc('Resume Flux resources for an app')]
flux-resume ns name:
    @flux resume kustomization {{ name }} -n {{ ns }}
    @flux resume helmrelease {{ name }} -n {{ ns }}
    @flux reconcile helmrelease {{ name }} -n {{ ns }} --force

[private]
[doc('Scale down an app (deployment or statefulset)')]
app-scale-down ns name:
    @CONTROLLER=$(kubectl -n {{ ns }} get deployment {{ name }} &>/dev/null && echo deployment || echo statefulset); \
        kubectl -n {{ ns }} scale $CONTROLLER/{{ name }} --replicas 0
    @kubectl -n {{ ns }} wait pod --for=delete --selector="app.kubernetes.io/name={{ name }}" --timeout=5m || true
