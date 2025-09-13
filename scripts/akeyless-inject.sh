########################################################################
# This is a Work in Progress (WIP), and untested.
# Please review and test before using in production.
# Feedback and contributions are welcome!
########################################################################
# Vibe-coded script to inject secrets from Akeyless into a file.
# Usage:
# ./scripts/akeyless-inject.sh <file-with-akeyless-references>
#
# The input file needs a reference in the format akeyless://secret/field
# Example:
# token: akeyless://talos/MACHINE_TOKEN
#
# This will replace the reference with the actual secret value
# Requires:
# `jq` and `akeyless CLI` installed and configured
# https://docs.akeyless.io/docs/cli
########################################################################

#!/usr/bin/env bash
set -Eeuo pipefail

# Load shared logging / checks
source "$(dirname "${0}")/lib/common.sh"

input_file="${1:-}"

if [[ -z "$input_file" || ! -f "$input_file" ]]; then
  log error "Usage: $0 <file-with-akeyless-references>"
  exit 1
fi

# Ensure required CLIs are present
check_cli "akeyless" "jq"

# Resolve akeyless:// references
resolve_secret() {
  local ref="$1"
  local path="${ref#akeyless://}"   # strip scheme
  local name="${path%%/*}"          # before first slash
  local field=""
  if [[ "$path" == */* ]]; then
    field="${path#*/}"              # after first slash
  fi

  # Strip any stray carriage returns (Windows line endings)
  name="${name//$'\r'/}"
  field="${field//$'\r'/}"

  log debug "Resolving secret reference" "ref=$ref" "name=$name" "field=$field"

  # Fetch secret value from Akeyless
  local raw
  if ! raw=$(akeyless get-secret-value --name "$name" 2>&1); then
    log error "Failed to fetch secret from Akeyless" "name=$name"
    exit 1
  fi

  # Always treat the secret as JSON and require a field
  if [[ -z "$field" ]]; then
    log error "Field must be specified for JSON secret" "name=$name"
    exit 1
  fi

  # Parse JSON field
  local extracted
  if ! extracted=$(echo "$raw" | jq -er --arg f "$field" '.[$f]' 2>&1); then
    log error "Secret is not valid JSON or missing field" "name=$name" "field=$field"
    exit 1
  fi

  printf '%s' "$extracted"
}

# Process file line by line
while IFS= read -r line || [[ -n "$line" ]]; do
  # Replace *all* akeyless:// refs in this line in one pass
  while [[ "$line" =~ (akeyless://[^[:space:]\"\'\)]+) ]]; do
    match="${BASH_REMATCH[1]}"
    replacement=$(resolve_secret "$match")

    log debug "Replacing match" "match=$match" "replacement=$replacement"

    # Replace all occurrences of this match in the line
    line=$(MATCH="$match" REPLACEMENT="$replacement" \
      perl -pe 's/\Q$ENV{MATCH}\E/$ENV{REPLACEMENT}/g' <<<"$line")

    # Break after one substitution pass for this match
    break
  done

  echo "$line"
done < "$input_file"
