#!/usr/bin/env bash
set -Eeuo pipefail

################################################################################
# Akeyless Secret Injection Script
################################################################################
# This is a Work in Progress (WIP), and only limited tests by myself.
# Please review and test before using. Feedback and contributions are welcome!
# Inspired by https://github.com/brunnels/
################################################################################
#
# Description:
#   Vibe-coded script with Claude that reads from standard input or a file and
#   replaces Akeyless secrets in the format "ak://<path>" or "ak://<path>/<key>"
#   with actual secret values fetched from Akeyless using the 'akeyless' CLI.
#
#   Supports both plain text secrets and JSON secrets with field extraction.
#
# Prerequisites:
#   1. The 'akeyless' CLI must be installed and available in your PATH
#      Installation: https://docs.akeyless.io/docs/cli
#   2. The 'jq' CLI must be installed for JSON parsing
#      Installation: apt-get install jq <OR> brew install jq
#   3. You must be authenticated with Akeyless
#      Configure: akeyless configure --access-type api_key --access-id <your_id> --access-key <your_key>
#
# Usage:
#   # From stdin (pipe):
#     echo "token: ak://talos/MACHINE_TOKEN" | ./scripts/akeyless-inject.sh
#
#   # From file:
#     ./scripts/akeyless-inject.sh ./talos/config.yaml.j2 > talos/config.yaml
#
#   # With template redirection:
#     cat secrets.yaml.tmpl | ./scripts/akeyless-inject.sh > secrets.yaml
#
# Formatting/Example References:
#   Plain text secret with support to nested paths:
#     ak://secret <OR> ak://path/to/secret
#     Example: ak://talos/token
#     Returns: The raw secret value stored at that path
#
#   JSON secret with field extraction:
#     ak://secret/FIELD_NAME
#     Example: 'token: ak://kubernetes/MACHINE_TOKEN'
#     Returns: The value of "MACHINE_TOKEN" key from the JSON secret
#
#   Nested path to JSON secret with field extraction:
#     ak://deeply/nested/path/to/secret/FIELD
#     Example: ak://prod/cluster-01/talos/control-plane/TOKEN
#     Returns: The value of "TOKEN" from the nested JSON secret
#
# Notes:
#   - The script processes input line by line and replaces ALL ak:// references
#   - Failed secret lookups will cause the script to exit with an error
#   - Set LOG_LEVEL environment variable to control verbosity (debug/info/warn/error)
#   - Strips carriage returns (\r) for cross-platform compatibility
#
################################################################################

# Load shared library
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
COMMON_LIB="${SCRIPT_DIR}/lib/common.sh"

if [[ ! -f "$COMMON_LIB" ]]; then
  echo "ERROR: Required library not found: ${COMMON_LIB}" >&2
  exit 1
fi

source "$COMMON_LIB"

# Ensure required CLIs are present, common.sh will exit on failure
check_cli "akeyless" "jq"

# Validate input
input_file="${1:-/dev/stdin}"

if [[ ! -f "$input_file" && "$input_file" != "/dev/stdin" ]]; then
  log error "Usage: $0 <file-with-akeyless-references> or pipe content to stdin"
  exit 1
fi

# Resolve ak:// references
resolve_secret() {
  local ref="$1"
  local path="${ref#ak://}"   # strip scheme

  # Strip carriage returns
  path="${path//$'\r'/}"

  log debug "Resolving secret reference" "ref=$ref" "path=$path"

  # Try as full path first (plain text or nested secret)
  local secret_value
  if secret_value=$(akeyless get-secret-value --name "$path" 2>&1); then
    log debug "Resolved as full-path secret" "name=$path"
    printf '%s' "$secret_value"
    return 0
  fi

  # If path has slash, try JSON field extraction
  if [[ "$path" == */* ]]; then
    local secret_name="${path%/*}"
    local json_key="${path##*/}"

    log debug "Attempting JSON field extraction" "name=$secret_name" "key=$json_key"

    # Fetch secret
    local secret_json
    if ! secret_json=$(akeyless get-secret-value --name "$secret_name" 2>&1); then
      log error "Failed to fetch secret from Akeyless" "name=$secret_name"
    fi

    # Validate key exists
    if ! echo "$secret_json" | jq -e "has(\"$json_key\")" > /dev/null 2>&1; then
      log error "Key not found in secret" "name=$secret_name" "key=$json_key"
    fi

    # Extract value
    if ! secret_value=$(echo "$secret_json" | jq -r ".\"$json_key\"" 2>&1); then
      log error "Failed to extract key from secret" "name=$secret_name" "key=$json_key"
    fi

    printf '%s' "$secret_value"
    return 0
  fi

  # No slash and full-path fetch failed
  log error "Secret not found" "name=$path"
}

# Process input line by line
while IFS= read -r line || [[ -n "$line" ]]; do
  # Match ak:// tokens (alphanumeric, slashes, dots, hyphens, underscores)
  while [[ "$line" =~ (ak://[a-zA-Z0-9/_.-]+) ]]; do
    token="${BASH_REMATCH[1]}"

    log debug "Found token"

    # Resolve the secret
    secret_value=$(resolve_secret "$token")

    log debug "Replacing token with" "$token"

    # Replace token with value
    line="${line/"$token"/"$secret_value"}"
  done

  echo "$line"
done < "$input_file"
