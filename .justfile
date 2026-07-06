#!/usr/bin/env -S just --justfile

set lazy
set positional-arguments
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Ansible Recipes
[group: 'Ansible']
mod ansible "ansible"

# Bootstrap Recipes
[group: 'Bootstrap']
mod bootstrap "kubernetes/bootstrap"

# Kubernetes Recipes
[group: 'Kubernetes']
mod kube "kubernetes"

# Talos Recipes
[group: 'Talos']
mod talos "kubernetes/talos"

[private]
[script]
default:
    just -l

[private]
[script]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
[script]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | bash kubernetes/bootstrap/scripts/akeyless-inject.sh

[private]
[script]
check-tools *tools:
    for tool in {{ tools }}; do \
        if ! command -v "$tool" &> /dev/null; then \
            just log fatal "Required tool not found" "tool" "$tool" "hint" "install via mise or your package manager"; \
        fi; \
    done
