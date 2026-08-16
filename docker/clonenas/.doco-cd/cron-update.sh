#!/bin/bash
# Self-update script for doco-cd + akeyless-proxy
# 1. Fetches each file from GitHub with `curl -sf` — aborts entirely if GitHub is unreachable
# 2. Compares SHA256 hashes against local copies
# 3. Only runs `docker compose up -d --pull always --force-recreate` if at least one file changed
# 4. Logs with timestamps to ~/.config/doco-cd/update.log

set -euo pipefail

WORK_DIR="/mnt/vault/sysadmin/.config/doco-cd"
BASE_URL="https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/clonenas/.doco-cd"
LOG_FILE="$WORK_DIR/update.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

cd "$WORK_DIR" || { log "ERROR: Cannot cd to $WORK_DIR"; exit 1; }

# Check Docker access before fetching. Without it the fetch still rewrites the
# files, the rebuild then fails, and the next run reports UNCHANGED and skips
# the rebuild - leaving updated files and a stale container.
docker info >/dev/null 2>&1 || { log "ERROR: no Docker access - re-run with sudo"; exit 1; }

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

if [ "$CHANGED" -eq 1 ]; then
  log "Pulling images and restarting doco-cd stack..."
  docker compose -f "$WORK_DIR/docker-compose.app.yaml" up -d --pull always --force-recreate
  log "Done."
else
  log "No changes — nothing to do."
fi
