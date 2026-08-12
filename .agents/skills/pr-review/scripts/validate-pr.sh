#!/usr/bin/env bash
# Validate the current working tree: renders every Kustomization and HelmRelease,
# then shellchecks touched shell scripts. Read-only — never touches the cluster.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

rc=0

echo "==> flate test all"
if mise exec -- flate test all; then
  echo "    PASS"
else
  status=$?
  echo "    FAIL (exit ${status})"
  if [[ ${status} -ne 0 ]]; then
    echo "    If this said 'basic credential not found', run: just kube registry-auth"
    echo "    Private ocharted charts need workstation OCI auth. Do not edit the"
    echo "    OCIRepositories to work around it."
  fi
  rc=1
fi

echo "==> shellcheck (changed shell scripts)"
mapfile -t scripts < <(
  { git diff --name-only --diff-filter=d HEAD
    git diff --cached --name-only --diff-filter=d
    git ls-files --others --exclude-standard
  } | sort -u | grep -E '\.sh$' || true
)

if [[ ${#scripts[@]} -eq 0 ]]; then
  echo "    SKIP (no shell scripts changed)"
else
  printf '    %s\n' "${scripts[@]}"
  if mise exec -- shellcheck "${scripts[@]}"; then
    echo "    PASS"
  else
    echo "    FAIL"
    rc=1
  fi
fi

echo
if [[ ${rc} -eq 0 ]]; then
  echo "All validation passed."
else
  echo "Validation failed."
fi
exit "${rc}"
