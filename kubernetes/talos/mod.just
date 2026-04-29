set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'
scripts_dir := kubernetes_dir + '/bootstrap/scripts'
talos_dir := kubernetes_dir + '/talos'
controller := `talosctl config info -o yaml | yq -e '.endpoints[0]'`
nodes := `talosctl config info -o yaml | yq -e '.nodes | join (",")'`

[private]
default:
    just -l talos

[private]
node-dir node:
    if [ -f "{{ talos_dir }}/controlplane/{{ node }}.yaml.j2" ]; then \
        echo "{{ talos_dir }}/controlplane"; \
    elif [ -f "{{ talos_dir }}/worker/{{ node }}.yaml.j2" ]; then \
        echo "{{ talos_dir }}/worker"; \
    else \
        echo "ERROR: no config found for node {{ node }}" >&2; exit 1; \
    fi

[doc('Apply Talos config to a node')]
apply-node node *args:
    just check-tools talosctl
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Download Talos machine image')]
download-image version schematic:
    just check-tools curl jq
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ talos_dir }}/talos-{{ version }}-{{ replace_regex(schematic, '^(.{8}).*', '$1') }}.iso" \
        "https://factory.talos.dev/image/{{ schematic }}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "{{ schematic }}"

[doc('Generate schematic ID from Talos schematic')]
gen-schematic-id node:
    just check-tools curl jq minijinja-cli akeyless
    node_dir="$(just talos node-dir {{ node }})"; \
    curl -sX POST --data-binary @<(just template "$node_dir/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[doc('Reboot a node')]
reboot-node node:
    just check-tools talosctl gum
    gum confirm "Reboot node {{ node }}?" --default="No" && \
        talosctl -n {{ node }} reboot -m powercycle || exit 0

[doc('Render Talos config for a node')]
render-config node:
    just check-tools talosctl minijinja-cli akeyless yq gum
    export node_dir="$(just talos node-dir {{ node }})"; \
    export IS_CONTROLLER="$(just talos machine-controller {{ node }})"; \
    export SCHEMATIC_ID="$(just talos gen-schematic-id {{ node }})"; \
    gum spin --title "Injecting secrets..." -- bash -c "\
        talosctl machineconfig patch <(just template '{{ talos_dir }}/machineconfig.yaml.j2') \
            -p @<(just template '$node_dir/{{ node }}.yaml.j2')"

[doc('Reset a node')]
reset-node node *args:
    just check-tools talosctl gum
    gum confirm "Reset node {{ node }}?" --default="No" && \
        talosctl -n "{{ node }}" reset --system-labels-to-wipe EPHEMERAL,STATE,u-local-hostpath --graceful=false --reboot {{ args }} || exit 0

[doc('Shutdown a node')]
shutdown-node node *args:
    just check-tools talosctl gum
    gum confirm "Shutdown node {{ node }}?" --default="No" && \
        talosctl -n "{{ node }}" shutdown --force {{ args }} || exit 0

[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    just check-tools talosctl
    talosctl -n "{{ controller }}" upgrade-k8s --to {{ version }}

[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    just check-tools talosctl
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image)" -m powercycle --timeout=10m {{ args }}

[private]
machine-controller node:
    node_dir="$(just talos node-dir {{ node }})"; \
    just template "$node_dir/{{ node }}.yaml.j2" | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
machine-image:
    just template "{{ talos_dir }}/machineconfig.yaml.j2" | yq -e 'select(.machine) | .machine.install.image'