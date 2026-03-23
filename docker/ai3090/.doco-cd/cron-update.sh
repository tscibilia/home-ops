#!/bin/bash
# Self-update script for doco-cd on ai3090 (Ubuntu 24.04)
# 1. Fetches docker-compose.app.yaml from GitHub — aborts entirely if unreachable
# 2. Compares SHA256 hash against local copy
# 3. If changed: docker compose pull && docker compose up -d
# 4. Logs with timestamps to ~/.config/doco-cd/update.log

set -euo pipefail

WORK_DIR="/home/ubuntu/.config/doco-cd"
BASE_URL="https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/ai3090/.doco-cd"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$WORK_DIR/update.log"

log() { echo "[$TIMESTAMP] $*" | tee -a "$LOG_FILE"; }

cd "$WORK_DIR" || { log "ERROR: Cannot cd to $WORK_DIR"; exit 1; }

CHANGED=0

fetch_and_compare() {
  local filename="$1"
  local url="$BASE_URL/$filename"

  local new_content
  new_content=$(curl -sf --max-time 30 "$url") || {
    log "ERROR: Failed to fetch $filename from GitHub — aborting"
    exit 1
  }

  local new_hash old_hash
  new_hash=$(echo "$new_content" | sha256sum | cut -d' ' -f1)
  old_hash=$(sha256sum "$filename" 2>/dev/null | cut -d' ' -f1 || echo "")

  if [ "$new_hash" != "$old_hash" ]; then
    log "CHANGED: $filename — updating"
    echo "$new_content" > "$filename"
    CHANGED=1
  else
    log "UNCHANGED: $filename"
  fi
}

fetch_and_compare "docker-compose.app.yaml"

if [ "$CHANGED" -eq 1 ]; then
  log "Restarting doco-cd..."
  docker compose -f docker-compose.app.yaml pull
  docker compose -f docker-compose.app.yaml up -d
  log "Done."
else
  log "No changes — nothing to do."
fi
