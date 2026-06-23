set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

controller := `talosctl config info -o yaml | yq -r -e '.endpoints[0]'`
nodes := `talosctl config info -o yaml | yq -r -e '([.endpoints // [], .nodes // []] | flatten | join(" "))'`

[private]
default:
    just -l talos

[doc('Apply Talos config to a node')]
apply-node node *args:
    just check-tools talosctl
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Download Talos machine image')]
download-image version:
    just check-tools curl jq
    export SCHEMATIC="$(just talos schematic-id)"
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ source_directory() }}/talos-{{ version }}-${SCHEMATIC:0:8}.iso" \
        "https://factory.talos.dev/image/${SCHEMATIC}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${SCHEMATIC}"

[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    just check-tools talosctl
    talosctl -n {{ node }} reboot -m powercycle

[doc('Render Talos config for a node')]
render-config node:
    just check-tools talosctl minijinja-cli akeyless yq gum
    export CONTROLPLANE="$(just talos machine-controller {{ node }})"; \
    export WORKER="$(just talos machine-worker {{ node }})"; \
    export SCHEMATIC="$(just talos schematic-id {{ node }})"; \
    gum spin --title "Injecting secrets..." -- bash -c "\
        talosctl machineconfig patch <(just template '{{ source_directory() }}/machineconfig.yaml.j2') \
            -p @<(just template '{{ source_directory() }}/nodes/{{ node }}.yaml.j2')"

[confirm('Reset node ' + node + ' [y|N] ?')]
[doc('Reset a single node')]
reset-node node *args:
    just check-tools talosctl
    talosctl -n "{{ node }}" reset --system-labels-to-wipe EPHEMERAL,STATE,u-local-hostpath --graceful=false --reboot {{ args }}

[confirm('Reset ALL nodes sequentially [y|N] ?')]
[doc('Reset all nodes safely (reduces Ceph size, drains, resets sequentially)')]
reset-cluster:
    just check-tools talosctl kubectl gum yq

    # Reduce Ceph replication to 1 to prevent I/O hangs during reset
    just log info "Reducing Ceph pool size to 1..."
    kubectl -n rook-ceph exec -l app=rook-ceph-tools -- ceph osd pool set ceph-blockpool size 1 || \
        just log warn "Could not reduce Ceph pool size (cluster may already be wiped)"

    # Cordon and drain all nodes
    just log info "Cordoning and draining all nodes..."
    kubectl get nodes -o name | xargs -I {} kubectl cordon {} 2>/dev/null || true
    kubectl drain --ignore-daemonsets --delete-emptydir-data --force --timeout=60s $(kubectl get nodes -o name) 2>/dev/null || true

    for node in {{ nodes }}; do
        gum confirm "Reset node $node?" --default="No" || continue

        just log info "Resetting $node..."
        if ! timeout 120 talosctl -n $node reset --system-labels-to-wipe EPHEMERAL,STATE,u-local-hostpath \
             --graceful=false --reboot 2>&1; then
            just log warn "Reset on $node timed out, forcing reboot..."
            talosctl -n $node reboot --mode force 2>/dev/null || true
        fi

        # Wait for node to reach maintenance mode before proceeding
        just log info "Waiting for $node to reach maintenance mode..."
        until talosctl get machineconfig -n $node --server 2>&1 | grep -q "config"; do
            sleep 5
        done
        just log info "Node $node reset complete"
    done

    just log info "All nodes reset. Run 'just bootstrap cluster' to rebuild."

[confirm('Shutdown node ' + node + ' [y|N] ?')]
[doc('Shutdown a node')]
shutdown-node node *args:
    just check-tools talosctl
    talosctl -n "{{ node }}" shutdown --force {{ args }}

[confirm('Upgrade Kubernetes to ' + version + ' [y|N] ?')]
[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    just check-tools talosctl
    talosctl -n "{{ controller }}" upgrade-k8s --to {{ version }}

[confirm('Upgrade node ' + node + ' to latest Talos [y|N] ?')]
[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    just check-tools talosctl
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image)" -m powercycle --timeout=10m {{ args }}

[private]
schematic-id node="":
    just check-tools curl jq minijinja-cli akeyless
    export CONTROLPLANE="$(if [ -n "{{ node }}" ]; then just talos machine-controller "{{ node }}" || true; fi)"
    export WORKER="$(if [ -n "{{ node }}" ]; then just talos machine-worker "{{ node }}" || true; fi)"
    curl -sX POST --data-binary @<(just template "{{ source_directory() }}/nodes/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[private]
machine-controller node:
    just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | yq -r -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
machine-worker node:
    just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | yq -r -e 'select(.machine) | (.machine.type == "worker") // ""'

[private]
machine-image:
    export SCHEMATIC="$(just talos schematic-id)"
    just template "{{ source_directory() }}/machineconfig.yaml.j2" | yq -r -e 'select(.machine) | .machine.install.image'
