#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="/opt/doco-cd"
BASE_URL="https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/vps/.doco-cd"
LOG_FILE="$WORK_DIR/update.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

cd "$WORK_DIR" || { log "ERROR: Cannot cd to $WORK_DIR"; exit 1; }

CHANGED=0

fetch_and_compare() {
  local filename="$1"
  local new_content
  new_content=$(curl -sf --max-time 30 "$BASE_URL/$filename") || {
    log "ERROR: Failed to fetch $filename from GitHub — aborting"
    exit 1
  }

  local new_hash old_hash
  new_hash=$(echo "$new_content" | sha256sum | cut -d' ' -f1)
  old_hash=$(sha256sum "$filename" 2>/dev/null | cut -d' ' -f1 || echo "")

  if [ "$new_hash" != "$old_hash" ]; then
    log "CHANGED: $filename"
    echo "$new_content" > "$filename"
    CHANGED=1
  else
    log "UNCHANGED: $filename"
  fi
}

fetch_and_compare "docker-compose.app.yaml"
fetch_and_compare "Dockerfile"
fetch_and_compare "proxy.py"

if [ "$CHANGED" -eq 1 ]; then
  log "Rebuilding and restarting doco-cd stack..."
  docker compose -f "$WORK_DIR/docker-compose.app.yaml" up -d --build --force-recreate
  log "Done."
else
  log "No changes — nothing to do."
fi
