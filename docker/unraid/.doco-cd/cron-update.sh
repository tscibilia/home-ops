#!/bin/bash
# Self-update script for doco-cd on Unraid
# 1. Fetches docker-compose.app.yaml from GitHub — aborts entirely if GitHub is unreachable
# 2. Compares SHA256 hash against local copy
# 3. If changed: parses new image tag, stops/removes doco-cd, runs new container
# 4. Logs with timestamps to /mnt/user/appdata/doco-cd/update.log
# NOTE: Uses plain docker commands — Unraid does not have docker compose

set -euo pipefail

WORK_DIR="/mnt/user/appdata/doco-cd"
BASE_URL="https://raw.githubusercontent.com/tscibilia/home-ops/main/docker/unraid/.doco-cd"
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
  log "Restarting doco-cd..."

  IMAGE=$(grep 'image:' "$WORK_DIR/docker-compose.app.yaml" | grep 'doco-cd' | awk '{print $2}')
  log "New image: $IMAGE"

  docker pull "$IMAGE"
  docker stop doco-cd 2>/dev/null || true
  docker rm doco-cd 2>/dev/null || true
  docker run -d \
    --name doco-cd \
    --restart unless-stopped \
    --network doco-cd \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v data:/data \
    -v "$WORK_DIR/gh_token:/run/secrets/gh_token:ro" \
    -e LOG_LEVEL=info \
    -e DEPLOY_CONFIG_BASE_DIR=./docker/unraid/ \
    -e POLL_CONFIG='- url: https://github.com/tscibilia/home-ops.git
  reference: refs/heads/main
  interval: 3600' \
    -e TZ=America/New_York \
    "$IMAGE"

  log "Done."
else
  log "No changes — nothing to do."
fi
