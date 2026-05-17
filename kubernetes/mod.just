set lazy
set positional-arguments
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
[script]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
[script]
apply-ks ns ks:
    just check-tools flux-local kubectl
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --field-manager=kustomize-controller -f /dev/stdin

[doc('Delete local Flux Kustomization')]
[script]
delete-ks ns ks:
    just check-tools flux-local kubectl
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

[doc('Browse a PVC')]
[script]
browse-pvc ns claim:
    just check-tools kubectl
    kubectl browse-pvc -n {{ ns }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Open a shell on a node')]
[script]
node-shell node:
    just check-tools kubectl
    kubectl debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
[script]
prune-pods:
    just check-tools kubectl
    for phase in Failed Pending Succeeded; do \
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done

[arg('resource', pattern='hr|ks|gitrepo|ocirepo|es')]
[doc('Sync a resource')]
[script]
sync resource ns='' app='':
    just check-tools kubectl
    _annotate() {
        kubectl -n "$1" annotate --field-manager flux-client-side-apply --overwrite {{ resource }} "$2" \
            "force-sync=$(date +%s)" \
            "reconcile.fluxcd.io/requestedAt=$(date +%s)" \
            "reconcile.fluxcd.io/forceAt=$(date +%s)"
    }
    if [ -n "{{ ns }}" ] && [ -n "{{ app }}" ]; then
        _annotate "{{ ns }}" "{{ app }}"
    else
        kubectl get {{ resource }} --no-headers -A | while read -r ns app _; do
            _annotate "$ns" "$app"
        done
    fi

[doc('Force a HelmRelease to reconcile from Source')]
[script]
reconcile-hr ns='' app='':
    just check-tools kubectl flux
    if [ -n "{{ ns }}" ] && [ -n "{{ app }}" ]; then
        flux reconcile helmrelease "{{ app }}" -n "{{ ns }}" --with-source
    else
        kubectl get hr --all-namespaces --no-headers | while read -r ns app _; do
            flux reconcile helmrelease "$app" -n "$ns" --with-source
        done
    fi

[doc('Restart all failed Flux HelmReleases')]
[script]
restart-hr:
    just check-tools kubectl flux
    kubectl get hr --all-namespaces | grep False | awk '{print $2, $1}' | while read -r name namespace; do \
        flux suspend helmrelease "$name" -n "$namespace"; \
        flux resume helmrelease "$name" -n "$namespace" & \
    done

[doc('Force a Kustomization to reconcile from Source')]
[script]
reconcile-ks ns='' app='':
    just check-tools kubectl flux
    if [ -n "{{ ns }}" ] && [ -n "{{ app }}" ]; then
        flux reconcile kustomization "{{ app }}" -n "{{ ns }}" --with-source
    else
        kubectl get ks --all-namespaces --no-headers | while read -r ns app _; do
            flux reconcile kustomization "$app" -n "$ns" --with-source
        done
    fi

[doc('Restart all failed Flux Kustomizations')]
[script]
restart-ks:
    just check-tools kubectl flux
    kubectl get ks --all-namespaces | grep False | awk '{print $2, $1}' | while read -r name namespace; do \
        flux suspend kustomization "$name" -n "$namespace"; \
        flux resume kustomization "$name" -n "$namespace" & \
    done

[arg('state', pattern='suspend|resume')]
[doc('Suspend or resume VolSync')]
[script]
volsync state:
    just check-tools flux kubectl
    flux -n volsync-system {{ state }} kustomization volsync
    flux -n volsync-system {{ state }} helmrelease volsync
    just kube keda {{ if state != "suspend" { "resume" } else { "suspend" } }} volsync-system volsync
    kubectl -n volsync-system scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Snapshot a VolSync PVC')]
[script]
volsync-snapshot ns='' app='':
    just check-tools kubectl
    _snapshot() {
        kubectl -n "$1" patch replicationsources "$2" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'
    }
    if [ -n "{{ ns }}" ] && [ -n "{{ app }}" ]; then
        _snapshot "{{ ns }}" "{{ app }}"
    else
        kubectl get replicationsources --no-headers -A | while read -r ns app _; do
            _snapshot "$ns" "$app"
        done
    fi

[doc('Unlock all VolSync restic source repos')]
[script]
volsync-unlock:
    just check-tools kubectl
    kubectl get replicationsources --all-namespaces --no-headers -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' | while IFS=',' read -r ns name; do \
        kubectl -n "$ns" patch --field-manager=flux-client-side-apply replicationsources "$name" --type merge -p "{\"spec\":{\"restic\":{\"unlock\":\"$(date +%s)\"}}}"; \
    done

[doc('List VolSync snapshots for an application')]
[script]
volsync-list ns app:
    just check-tools kubectl envsubst
    echo "Listing snapshots for {{ app }} in {{ ns }} namespace..."
    export NS="{{ ns }}" APP="{{ app }}" && \
        envsubst < {{ kubernetes_dir }}/components/volsync/resources/list.yaml.j2 | kubectl apply -f -
    kubectl -n {{ ns }} wait job/{{ app }}-list-snapshots --for=condition=complete --timeout=5m
    kubectl -n {{ ns }} logs job/{{ app }}-list-snapshots
    kubectl -n {{ ns }} delete job {{ app }}-list-snapshots

[doc('Restore VolSync backup for an application')]
[script]
volsync-restore ns app previous='0':
    just check-tools kubectl flux envsubst jq
    if kubectl -n {{ ns }} get scaledobject {{ app }} &>/dev/null; then \
        just kube keda suspend "{{ ns }}" "{{ app }}"; \
    fi
    flux -n {{ ns }} suspend kustomization {{ app }}
    flux -n {{ ns }} suspend helmrelease {{ app }}
    kubectl -n {{ ns }} get deploy,sts -l app.kubernetes.io/name={{ app }} -o name \
        | xargs -r -I{} kubectl -n {{ ns }} scale {} --replicas=0
    kubectl -n {{ ns }} wait pod --for=delete --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
    eval $(kubectl -n {{ ns }} get replicationsources/{{ app }} -o json | jq -r '"export CLAIM=\(.spec.sourcePVC) STORAGE_CLASS=\(.spec.restic.storageClassName) ACCESS_MODES=\(.spec.restic.accessModes[0]) PUID=\(.spec.restic.moverSecurityContext.runAsUser) PGID=\(.spec.restic.moverSecurityContext.runAsGroup)"') && \
        export NS="{{ ns }}" APP="{{ app }}" PREVIOUS="{{ previous }}" && \
        envsubst < {{ kubernetes_dir }}/components/volsync/resources/replicationdestination.yaml.j2 | kubectl apply -f -
    echo "Waiting for restore..."
    kubectl -n {{ ns }} wait job/volsync-dst-{{ app }}-manual --for=create --timeout=120s
    kubectl -n {{ ns }} wait job/volsync-dst-{{ app }}-manual --for=condition=complete --timeout=120m
    kubectl -n {{ ns }} delete replicationdestination {{ app }}-manual
    flux -n {{ ns }} resume kustomization {{ app }}
    flux -n {{ ns }} resume helmrelease {{ app }}
    flux -n {{ ns }} reconcile helmrelease {{ app }} --force
    kubectl -n {{ ns }} wait pod --for=condition=ready --selector="app.kubernetes.io/name={{ app }}" --timeout=5m || true
    if kubectl -n {{ ns }} get scaledobject {{ app }} &>/dev/null; then \
        just kube keda resume "{{ ns }}" "{{ app }}"; \
    fi
    echo "Restore complete!"

[doc('Restart network stack in dependency order')]
[script]
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
    just log info "Restarting External-DNS..."
    kubectl rollout restart deployment/external-dns -n network
    kubectl rollout status deployment/external-dns -n network --timeout=120s
    just log info "Restarting unifi-dns..."
    kubectl rollout restart deployment/unifi-dns -n network
    kubectl rollout status deployment/unifi-dns -n network --timeout=120s
    just log info "Restarting Envoy-Gateway..."
    kubectl rollout restart deployment/envoy-gateway -n network
    kubectl rollout status deployment/envoy-gateway -n network --timeout=120s
    just log info "Restarting Envoy gateways..."
    kubectl rollout restart deployment/envoy-internal deployment/envoy-external -n network
    kubectl rollout status deployment/envoy-internal -n network --timeout=120s
    kubectl rollout status deployment/envoy-external -n network --timeout=120s
    just log info "Network stack restart complete"

[private]
[script]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"

[private]
[script]
keda state ns='' app='':
    just check-tools kubectl
    _keda() {
        kubectl -n "$1" annotate --field-manager flux-client-side-apply --overwrite so "$2" autoscaling.keda.sh/paused{{ if state != "suspend" { "-" } else { "=true" } }}
    }
    if [ -n "{{ ns }}" ] && [ -n "{{ app }}" ]; then
        _keda "{{ ns }}" "{{ app }}"
    else
        kubectl get scaledobjects --no-headers -A | while read -r ns app _; do
            _keda "$ns" "$app"
        done
    fi
