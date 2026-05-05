set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

ansible_dir := justfile_dir() + '/ansible'

[private]
default:
    just -l ansible

[doc('Bootstrap VPS (subsequent runs — ubuntu user, port 22222)')]
bootstrap-vps *args:
    ansible-playbook -i {{ ansible_dir }}/inventory/hosts.yaml {{ ansible_dir }}/vps/playbook.yaml \
        --limit vps \
        --private-key ~/.ssh/home-ops \
        {{ args }}

[doc('Bootstrap VPS first run (root user, port 22)')]
bootstrap-vps-init *args:
    ansible-playbook -i {{ ansible_dir }}/inventory/hosts.yaml {{ ansible_dir }}/vps/playbook.yaml \
        --limit vps \
        --extra-vars "ansible_user=root ansible_port=22 bootstrap_mode=true" \
        --private-key ~/.ssh/home-ops \
        {{ args }}

[doc('Bootstrap TrueNAS doco-cd')]
bootstrap-truenas *args:
    ansible-playbook -i {{ ansible_dir }}/inventory/hosts.yaml {{ ansible_dir }}/truenas/playbook.yaml \
        --limit truenas \
        --private-key ~/.ssh/home-ops \
        {{ args }}

[doc('Dry-run VPS bootstrap')]
check-vps:
    just ansible bootstrap-vps --check

[doc('Dry-run TrueNAS bootstrap')]
check-truenas:
    just ansible bootstrap-truenas --check
