#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="/opt/doco-cd"
REPO_RAW="https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/vps/.doco-cd"
LOG_FILE="/var/log/doco-cd-update.log"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG_FILE"; }

cd "$WORK_DIR"

log "Fetching latest stack files..."
curl -fsSL "$REPO_RAW/docker-compose.app.yaml" -o docker-compose.yaml
curl -fsSL "$REPO_RAW/Dockerfile" -o Dockerfile
curl -fsSL "$REPO_RAW/proxy.py" -o proxy.py

log "Restarting stack..."
docker compose up -d --build

log "Done."
