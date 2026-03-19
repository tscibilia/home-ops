#!/bin/bash
# Self-update script for doco-cd + akeyless-proxy
# 1. Fetches each file from GitHub with `curl -sf` — aborts entirely if GitHub is unreachable
# 2. Compares SHA256 hashes against local copies
# 3. Only runs `docker compose up -d --build --force-recreate` if at least one file changed
# 4. Logs with timestamps to `/var/log/doco-cd-update.log`

set -euo pipefail

WORK_DIR="/mnt/nas/data/users/sysadmin/.config/doco-cd"
BASE_URL="https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/truenas/.doco-cd"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$TIMESTAMP] $*"; }

cd "$WORK_DIR" || { log "ERROR: Cannot cd to $WORK_DIR"; exit 1; }

CHANGED=0

fetch_and_compare() {
  local filename="$1"
  local url="$BASE_URL/$filename"

  local new_content
  new_content=$(curl -sf --max-time 30 "$url") || {
    log "ERROR: Failed to fetch $filename from GitHub (outage or network issue) — aborting"
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
fetch_and_compare "Dockerfile"

if [ "$CHANGED" -eq 1 ]; then
  log "Rebuilding and restarting doco-cd stack..."
  docker compose -f "$WORK_DIR/docker-compose.app.yaml" up -d --build --force-recreate
  log "Done."
else
  log "No changes — nothing to do."
fi
