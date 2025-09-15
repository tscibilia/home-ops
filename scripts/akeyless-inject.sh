########################################################################
# This is a Work in Progress (WIP), and untested.
# Please review and test before using in production.
# Feedback and contributions are welcome!
# Inspired by https://github.com/brunnels/
########################################################################
# Vibe-coded script to inject secrets from Akeyless into a file.
# Usage:
# Pipe any string or file content to this script.
#   echo "token: ak://talos/MACHINE_TOKEN" | ./scripts/akeyless-inject.sh
# or
#   ./scripts/akeyless-inject.sh <file-with-akeyless-references>
#
# The input needs a reference in the format ak://secret/field
# Examples:
#   token: ak://talos/MACHINE_TOKEN (for JSON secrets)
#   token: ak://talos (for plain text secrets)
#   token: ak://path/to/secret/TOKEN (for nested JSON secrets)
#
# Requires:
#   `jq` and `akeyless CLI` installed, configured and authenticated.
#   https://docs.akeyless.io/docs/cli
########################################################################

#!/usr/bin/env bash
set -Eeuo pipefail

# Load shared logging / checks
source "$(dirname "${0}")/lib/common.sh"

input_file="${1:-/dev/stdin}"

if [[ ! -f "$input_file" && "$input_file" != "/dev/stdin" ]]; then
  log error "Usage: $0 <file-with-akeyless-references> or pipe content to stdin"
  exit 1
fi

# Ensure required CLIs are present
check_cli "akeyless" "jq"

# Resolve ak:// references
resolve_secret() {
  local ref="$1"
  local path="${ref#ak://}"   # strip scheme

  # Strip stray carriage returns
  path="${path//$'\r'/}"

  log debug "Resolving secret reference" "ref=$ref" "path=$path"

  # 1) Prefer exact full path (handles nested plain-text secrets like /kubernetes/bootstrap/Secret)
  local raw_full
  if raw_full=$(akeyless get-secret-value --name "$path" 2>&1); then
    log debug "Resolved as full-path secret" "name=$path"
    printf '%s' "$raw_full"
    return 0
  fi

  # 2) Fallback: treat last segment as JSON field, parent as secret name
  if [[ "$path" == */* ]]; then
    local name="${path%/*}"
    local field="${path##*/}"

    log debug "Attempting JSON field extraction" "name=$name" "field=$field"

    local raw_parent
    if ! raw_parent=$(akeyless get-secret-value --name "$name" 2>&1); then
      log error "Failed to fetch secret from Akeyless" "name=$name"
      exit 1
    fi

    local extracted
    if ! extracted=$(echo "$raw_parent" | jq -er --arg f "$field" '.[$f]' 2>&1); then
      log error "Secret is not valid JSON or missing field" "name=$name" "field=$field"
      exit 1
    fi

    printf '%s' "$extracted"
    return 0
  fi

  # 3) No slash and full-path fetch failed → nothing to do
  log error "Secret not found and no JSON field to extract" "name=$path"
  exit 1
}

# Process file line by line
while IFS= read -r line || [[ -n "$line" ]]; do
  # Replace *all* ak:// refs in this line in one pass
  while [[ "$line" =~ (ak://[^[:space:]\"\'\)]+) ]]; do
    match="${BASH_REMATCH[1]}"
    replacement=$(resolve_secret "$match")

    log debug "Replacing match" "match=$match" "replacement=$replacement"

    # Safe literal replacement using Perl with env vars
    line=$(MATCH="$match" REPLACEMENT="$replacement" \
      perl -pe 's/\Q$ENV{MATCH}\E/$ENV{REPLACEMENT}/g' <<<"$line")

    # Break after one substitution pass for this match
    break
  done

  echo "$line"
done < "$input_file"
