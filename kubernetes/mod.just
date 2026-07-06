set default-script
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
    just check-tools flate kubectl
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --field-manager=kustomize-controller -f /dev/stdin

[doc('Delete local Flux Kustomization')]
[script]
delete-ks ns ks:
    just check-tools flate kubectl
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

[doc('Browse a PVC')]
[script]
browse-pvc ns claim:
    just check-tools kubectl
    kubectl browse-pvc -n {{ ns }} -i mirror.gcr.io/alpine:latest {{ claim }}

[doc('Open a shell on a node')]
[script]
debug-node node:
    just check-tools kubectl
    trap 'kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug --field-selector spec.nodeName={{ node }} --ignore-not-found --wait=false' EXIT
    kubectl debug node/{{ node }} -n default -it --image=mirror.gcr.io/alpine:latest --profile=sysadmin

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

[doc('Trigger a manual Kopiur snapshot')]
[script]
snapshot ns app:
    just check-tools kubectl kopiur
    kubectl kopiur snapshot now --policy {{ app }} -n {{ ns }} --wait --logs

[doc('Restore a Kopiur snapshot for an app (in-place, direct-to-PVC, optional offset)')]
[script]
restore ns app offset='0':
    just check-tools kubectl kopiur
    flux -n {{ ns }} suspend kustomization {{ app }}
    flux -n {{ ns }} suspend helmrelease {{ app }}
    kubectl -n {{ ns }} get deploy,sts -l app.kubernetes.io/name={{ app }} -o name \
        | xargs -r -I{} kubectl -n {{ ns }} scale {} --replicas=0
    kubectl -n {{ ns }} wait pod --for=delete --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
    kubectl kopiur restore --from-policy {{ app }} --to-pvc {{ app }} -n {{ ns }} --wait --logs --offset {{ offset }}
    flux -n {{ ns }} resume kustomization {{ app }}
    flux -n {{ ns }} resume helmrelease {{ app }}
    flux -n {{ ns }} reconcile helmrelease {{ app }} --force
    kubectl -n {{ ns }} wait pod --for=condition=ready --selector="app.kubernetes.io/name={{ app }}" --timeout=5m

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
    flate build ks -n "{{ ns }}" -o yaml "{{ ks }}"
