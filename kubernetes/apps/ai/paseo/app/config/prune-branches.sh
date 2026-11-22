#!/usr/bin/env bash
# Paseo branch maintenance across every project checkout.
#
# Fast-forwards each project's local default branch and deletes local branches
# whose work already landed on the remote default branch. A branch is deleted
# only when it is not checked out in any worktree, has no open pull request,
# and its tip is an ancestor of the remote default branch, patch-equivalent to
# it, or the head of a merged pull request. Everything else is reported kept.
#
# This file is rendered by a Flux Kustomization with postBuild substitution,
# which rewrites dollar-open-brace expressions in every resource. Keep this
# script free of brace-style shell expansions (no substring, array-default or
# pattern-removal forms); use plain "$var" and the helpers below instead.
#
# Environment: PROJECTS_ROOT, WORKTREES_ROOT, DRY_RUN=1, MIN_AGE_HOURS.

set -o pipefail

[ -n "$PROJECTS_ROOT" ] || PROJECTS_ROOT=/home/paseo/workspace
[ -n "$WORKTREES_ROOT" ] || WORKTREES_ROOT=/workspace/worktrees
[ -n "$DRY_RUN" ] || DRY_RUN=0
[ -n "$MIN_AGE_HOURS" ] || MIN_AGE_HOURS=24
export GIT_TERMINAL_PROMPT=0

cutoff=$(( $(date +%s) - MIN_AGE_HOURS * 3600 ))
deleted_total=0
kept_total=0

log() { printf '%s\n' "$*"; }

for repo in "$PROJECTS_ROOT"/*; do
  [ -d "$repo" ] || continue
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || continue
  log "== $(basename "$repo")"

  default_ref=$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  [ -n "$default_ref" ] || default_ref=origin/main
  if ! git -C "$repo" show-ref --verify --quiet "refs/remotes/$default_ref"; then
    log "   no $default_ref, skipped"
    continue
  fi
  default_branch=$(printf '%s' "$default_ref" | cut -d/ -f2-)

  if ! timeout 120 git -C "$repo" fetch --prune --quiet origin; then
    log "   fetch failed, skipped (no deletions on stale refs)"
    continue
  fi

  declare -A checked=() open_prs=() merged_heads=()
  while IFS= read -r br; do
    checked[$br]=1
  done < <(git -C "$repo" worktree list --porcelain | sed -n 's|^branch refs/heads/||p')

  if command -v gh >/dev/null 2>&1 &&
    git -C "$repo" remote get-url origin 2>/dev/null | grep -q 'github\.com'; then
    while IFS=$'\t' read -r kind sha ref; do
      [ -n "$ref" ] || continue
      case $kind in
        open) open_prs[$ref]=1 ;;
        merged) merged_heads[$sha]=1 ;;
      esac
    done < <(
      cd "$repo" || exit 0
      exec 2>/dev/null
      timeout 120 gh pr list --state open --limit 300 \
        --json headRefName,headRefOid --jq '.[] | ["open", .headRefOid, .headRefName] | @tsv'
      timeout 120 gh pr list --state merged --limit 300 \
        --json headRefName,headRefOid --jq '.[] | ["merged", .headRefOid, .headRefName] | @tsv'
    )
  fi

  if [[ -v checked[$default_branch] ]]; then
    log "   $default_branch checked out, not fast-forwarded"
  elif git -C "$repo" show-ref --verify --quiet "refs/heads/$default_branch"; then
    local_tip=$(git -C "$repo" rev-parse "refs/heads/$default_branch")
    remote_tip=$(git -C "$repo" rev-parse "refs/remotes/$default_ref")
    short_local=$(git -C "$repo" rev-parse --short=9 "$local_tip")
    short_remote=$(git -C "$repo" rev-parse --short=9 "$remote_tip")
    if [ "$local_tip" = "$remote_tip" ]; then
      log "   $default_branch current"
    elif [ "$(git -C "$repo" rev-list --count "$remote_tip..$local_tip")" = 0 ]; then
      if [ "$DRY_RUN" = 1 ]; then
        log "   would fast-forward $default_branch $short_local -> $short_remote"
      else
        git -C "$repo" update-ref "refs/heads/$default_branch" "$remote_tip" "$local_tip"
        log "   fast-forwarded $default_branch $short_local -> $short_remote"
      fi
    else
      log "   $default_branch has local commits, not fast-forwarded"
    fi
  fi

  while IFS= read -r branch; do
    [ "$branch" = "$default_branch" ] && continue
    if [[ -v checked[$branch] ]]; then
      log "   keep $branch (checked out)"
      ((kept_total++))
      continue
    fi
    if [[ -v open_prs[$branch] ]]; then
      log "   keep $branch (open PR)"
      ((kept_total++))
      continue
    fi
    tip=$(git -C "$repo" rev-parse --verify --quiet "refs/heads/$branch") || continue
    tip_time=$(git -C "$repo" log -1 --format=%ct "$tip" 2>/dev/null || echo 0)
    if [ "$tip_time" -gt "$cutoff" ]; then
      log "   keep $branch (recent)"
      ((kept_total++))
      continue
    fi

    reason=
    if [[ -v merged_heads[$tip] ]]; then
      reason="merged PR"
    elif git -C "$repo" merge-base --is-ancestor "$tip" "refs/remotes/$default_ref"; then
      reason="ancestor of $default_ref"
    elif ! git -C "$repo" cherry "refs/remotes/$default_ref" "$tip" | grep -q '^+'; then
      reason="patches on $default_ref"
    fi

    if [ -z "$reason" ]; then
      log "   keep $branch (unique commits)"
      ((kept_total++))
      continue
    fi
    if [ "$DRY_RUN" = 1 ]; then
      log "   would delete $branch ($reason)"
      ((deleted_total++))
    elif git -C "$repo" branch -D "$branch" >/dev/null 2>&1; then
      log "   deleted $branch ($reason)"
      ((deleted_total++))
    else
      log "   keep $branch (delete failed)"
      ((kept_total++))
    fi
  done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads)

  [ "$DRY_RUN" = 1 ] || git -C "$repo" worktree prune
done

if [ -d "$WORKTREES_ROOT" ]; then
  while IFS= read -r dir; do
    if [ "$DRY_RUN" = 1 ]; then
      log "would remove empty $dir"
    elif rmdir "$dir" 2>/dev/null; then
      log "removed empty $dir"
    fi
  done < <(find "$WORKTREES_ROOT" -mindepth 1 -maxdepth 2 -type d -empty 2>/dev/null)
fi

log ""
log "deleted $deleted_total branch(es), kept $kept_total"
[ "$DRY_RUN" = 1 ] && log "(dry run)"
exit 0
