#!/usr/bin/env -S just --justfile

set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
mod kube "kubernetes"
mod talos "talos"

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | bash bootstrap/scripts/akeyless-inject.sh

[private]
check-tools *tools:
    for tool in {{ tools }}; do \
        if ! command -v "$tool" &> /dev/null; then \
            just log fatal "Required tool not found" "tool" "$tool" "hint" "install via mise or your package manager"; \
        fi; \
    done