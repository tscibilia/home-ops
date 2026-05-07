set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

ansible_dir := justfile_dir() + '/ansible'

[private]
default:
    just -l ansible

[doc('Install Ansible collections required for VPS playbook')]
install-collections:
    ansible-galaxy collection install -r "{{ ansible_dir }}/requirements.yml"

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

[doc('Restart doco-cd container on a docker host (truenas|unraid|vps)')]
restart-doco-cd host:
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
deploy-direct service:
    #!/usr/bin/env bash
    set -euo pipefail
    deploy_dir="/var/lib/docker/volumes/doco-cd_data/_data/github.com/tscibilia/home-ops/docker/vps/{{ service }}"
    scp -i ~/.ssh/home-ops -P 22222 \
        "{{ justfile_directory() }}/docker/vps/{{ service }}/docker-compose.yaml" \
        "ubuntu@vps.internal:/tmp/compose-deploy.yaml"
    ssh -i ~/.ssh/home-ops -p 22222 ubuntu@vps.internal \
        "mv /tmp/compose-deploy.yaml $deploy_dir/docker-compose.yaml && \
         cd $deploy_dir && docker compose up -d --remove-orphans"
