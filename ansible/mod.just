set lazy
set positional-arguments
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

ansible_dir := justfile_dir() + '/ansible'

[private]
[script]
default:
    just -l ansible

[doc('Install Ansible collections required for VPS playbook')]
[script]
install-collections:
    just check-tools ansible-galaxy
    ansible-galaxy collection install -r "{{ ansible_dir }}/requirements.yml"

[doc('Bootstrap VPS (subsequent runs — ubuntu user, port 22222)')]
[script]
bootstrap-vps *args:
    just check-tools ansible-playbook
    ansible-playbook -i {{ ansible_dir }}/inventory/hosts.yaml {{ ansible_dir }}/vps/playbook.yaml \
        --limit vps \
        --private-key ~/.ssh/home-ops \
        {{ args }}

[doc('Bootstrap VPS first run (root user, port 22)')]
[script]
bootstrap-vps-init *args:
    just check-tools ansible-playbook
    ansible-playbook -i {{ ansible_dir }}/inventory/hosts.yaml {{ ansible_dir }}/vps/playbook.yaml \
        --limit vps \
        --extra-vars "ansible_user=root ansible_port=22 bootstrap_mode=true" \
        --private-key ~/.ssh/home-ops \
        {{ args }}

[doc('Bootstrap TrueNAS doco-cd')]
[script]
bootstrap-truenas *args:
    just check-tools ansible-playbook
    ansible-playbook -i {{ ansible_dir }}/inventory/hosts.yaml {{ ansible_dir }}/truenas/playbook.yaml \
        --limit truenas \
        --private-key ~/.ssh/home-ops \
        {{ args }}

[doc('Dry-run VPS bootstrap')]
[script]
check-vps:
    just ansible bootstrap-vps --check

[doc('Dry-run TrueNAS bootstrap')]
[script]
check-truenas:
    just ansible bootstrap-truenas --check

[doc('Restart doco-cd container on a docker host (truenas|unraid|vps)')]
[script]
restart-doco-cd host:
    just check-tools ssh
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ host }}" in
      truenas)
        ssh -i ~/.ssh/home-ops sysadmin@truenas.internal "docker restart doco-cd"
        ;;
      unraid)
        ssh -i ~/.ssh/home-ops root@unraid.internal "docker restart doco-cd"
        ;;
      vps)
        ssh -i ~/.ssh/home-ops -p 22222 ubuntu@vps.internal "docker restart doco-cd"
        ;;
      *)
        echo "Unknown host: {{ host }}. Valid: truenas, unraid, vps" >&2
        exit 1
        ;;
    esac

[doc('Emergency: SCP compose file directly to VPS and restart service (bypasses doco-cd/git)')]
[script]
deploy-direct service:
    just check-tools ssh scp
    #!/usr/bin/env bash
    set -euo pipefail
    deploy_dir="/var/lib/docker/volumes/doco-cd_data/_data/github.com/tscibilia/home-ops/docker/vps/{{ service }}"
    scp -i ~/.ssh/home-ops -P 22222 \
        "{{ justfile_directory() }}/docker/vps/{{ service }}/docker-compose.yaml" \
        "ubuntu@vps.internal:/tmp/compose-deploy.yaml"
    ssh -i ~/.ssh/home-ops -p 22222 ubuntu@vps.internal \
        "mv /tmp/compose-deploy.yaml $deploy_dir/docker-compose.yaml && \
         cd $deploy_dir && docker compose up -d --remove-orphans"
