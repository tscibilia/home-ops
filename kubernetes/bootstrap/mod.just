set default-script
set no-exit-message
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

controller := `talosctl config info -o yaml | yq -r -e '.endpoints[0]'`
nodes := `talosctl config info -o yaml | yq -r -e '([.endpoints // [], .nodes // []] | flatten | join(" "))'`

[private]
default:
    just -l bootstrap

[confirm('Bootstrap cluster? [y|N]')]
[doc('Bootstrap Cluster')]
cluster: talos kube (kubeconfig "node") wait namespaces resources crds apps cnpg kubeconfig

[private]
talos:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools talosctl yq
    for n in {{ nodes }}; do
        if ! op=$(just --yes talos apply-node "$n" --insecure 2>&1); then
            if [[ "$op" == *"certificate required"* ]]; then
                just log info "Talos already configured, skipping apply of config" "stage" "{{ recipe_name() }}" "node" "$n"
                continue
            fi
            just log fatal "Failed to apply Talos configuration" "stage" "{{ recipe_name() }}" "node" "$n" "output" "$op"
        fi
    done

[private]
kube:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools talosctl
    until op=$(talosctl -n "{{ controller }}" bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do
        just log info "Kubernetes bootstrap in progress. Retrying in 5 seconds..." "stage" "{{ recipe_name() }}"
        sleep 5
    done

[private]
kubeconfig lb="cilium":
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools talosctl kubectl
    if ! talosctl kubeconfig -n "{{ controller }}" -f --force-context-name main {{ justfile_dir() }}; then
        just log fatal "Failed to fetch kubeconfig" "stage" "{{ recipe_name() }}"
    fi
    if [[ "{{ lb }}" != "cilium" ]]; then
        if ! kubectl config set-cluster main --server "https://{{ controller }}:6443"; then
            just log fatal "Failed to set kubectl cluster server address" "stage" "{{ recipe_name() }}"
        fi
    fi

[private]
wait:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools kubectl
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "{{ recipe_name() }}"
            sleep 5
        done
    fi

[private]
namespaces:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools kustomize yq kubectl
    find "{{ source_directory() }}/../apps" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r dir; do
        if ! kustomize build "$dir" | yq ea -e 'select(.kind == "Namespace")' | kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -; then
            just log fatal "Failed to apply namespace" "stage" "{{ recipe_name() }}" "namespace" "$(basename "$dir")"
        fi
    done

[private]
resources:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools minijinja-cli kubectl akeyless jq gum
    if ! gum spin --title "Injecting secrets..." -- just template "{{ source_directory() }}/resources.yaml.j2" | kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -; then
        just log fatal "Failed to apply resources" "stage" "{{ recipe_name() }}"
    fi

[private]
crds:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools helmfile kubectl
    if ! helmfile -f "{{ source_directory() }}/helmfile.d/00-crds.yaml" template -q | yq ea -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -; then
        just log fatal "Failed to apply crds" "stage" "{{ recipe_name() }}"
    fi

[private]
apps:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools helmfile
    export SECRET_DOMAIN="$(kubectl get secret -n flux-system cluster-secrets -o jsonpath='{.data.SECRET_DOMAIN}' | base64 -d)"
    if ! helmfile -f "{{ source_directory() }}/helmfile.d/01-apps.yaml" sync --hide-notes; then
        just log fatal "Failed to sync helmfile" "stage" "{{ recipe_name() }}"
    fi

[doc('Create CNPG clusters with recovery (runs during bootstrap if backups exist)')]
cnpg:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    just check-tools kustomize kubectl
    # Wait for CNPG operator to be ready
    until kubectl wait --for=condition=available deployment/cnpg-operator-cloudnative-pg -n database --timeout=5s &>/dev/null; do
        just log info "Waiting for CNPG operator to be ready. Retrying in 5 seconds..." "stage" "{{ recipe_name() }}"
        sleep 5
    done
    # Delete clusters that were created with initdb (Flux race) so recovery can proceed
    for cluster in pgsql-cluster pgvector-cluster; do
        if kubectl get cluster -n database "$cluster" &>/dev/null; then
            bootstrap=$(kubectl get cluster -n database "$cluster" -o jsonpath='{.spec.bootstrap}' 2>/dev/null)
            if echo "$bootstrap" | grep -q '"initdb"'; then
                just log info "Cluster $cluster exists with initdb bootstrap, deleting for recovery..." "stage" "{{ recipe_name() }}" "cluster" "$cluster"
                kubectl delete cluster -n database "$cluster"
            fi
        fi
    done
    # Apply clusters with recovery - if backups do not exist, cluster creation will fail and continue normally via Flux
    if ! kustomize build "{{ source_directory() }}/cnpg" | kubectl apply --server-side --field-manager bootstrap --force-conflicts -f - 2>&1; then
        just log info "CNPG cluster creation failed (likely no backups exist). Clusters will be created by Flux." "stage" "{{ recipe_name() }}"
    fi
