set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just check-tools flux-local kubectl
    just k8s render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --field-manager=kustomize-controller -f /dev/stdin

[doc('Browse a PVC')]
browse-pvc namespace claim:
    just check-tools kubectl
    kubectl browse-pvc -n {{ namespace }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just check-tools flux-local kubectl
    just k8s render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

[doc('Restart all failed HelmReleases')]
hr-restart:
    just check-tools kubectl flux
    kubectl get hr --all-namespaces | grep False | awk '{print $2, $1}' | while read -r name namespace; do \
        flux suspend helmrelease "$name" -n "$namespace"; \
        flux resume helmrelease "$name" -n "$namespace" &; \
    done

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

[doc('Force Flux to reconcile from Git')]
reconcile:
    just check-tools flux
    flux --namespace flux-system reconcile kustomization flux-system --with-source

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

[doc('Snapshot VolSync PVCs')]
snapshot:
    just check-tools kubectl
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" patch replicationsources "$name" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'; \
    done

[doc('Suspend or resume Keda ScaledObjects')]
keda state:
    just check-tools kubectl
    kubectl get scaledobjects --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite so "$name" autoscaling.keda.sh/paused{{ if state != "suspend" { "-" } else { "=true" } }}; \
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

[doc('Sync ExternalSecrets')]
sync-es:
    just check-tools kubectl
    kubectl get es --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite es "$name" force-sync="$(date +%s)"; \
    done

[doc('Sync GitRepositories')]
sync-git:
    just check-tools kubectl
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync HelmReleases')]
sync-hr:
    just check-tools kubectl
    kubectl get hr --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite hr "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"; \
    done

[doc('Sync Kustomizations')]
sync-ks:
    just check-tools kubectl
    kubectl get ks --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ks "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync OCIRepositories')]
sync-oci:
    just check-tools kubectl
    kubectl get ocirepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite ocirepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('View a secret')]
view-secret namespace secret:
    just check-tools kubectl
    kubectl view-secret -n {{ namespace }} {{ secret }}

[private]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"