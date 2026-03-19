#!/usr/bin/env bash
# Claude Code WorktreeCreate hook — creates the worktree and runs setup.
#
# Contract:
#   - Receives JSON on stdin with 'name' field
#   - Must print the absolute worktree path on stdout (nothing else!)
#   - Progress output goes to /dev/tty
#
# Reads .worktree.yml from the repo root for configuration.
#
# Dependencies: jq, yq (https://github.com/mikefarah/yq)
set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
REPO_PATH="$CLAUDE_PROJECT_DIR"
WORKTREE_PATH="${REPO_PATH}/.claude/worktrees/${NAME}"
BRANCH="worktree-${NAME}"
CONFIG="${REPO_PATH}/.worktree.yml"

# Progress goes to /dev/tty — stdout is reserved for Claude
TTY=/dev/tty
log() { echo "$*" > "$TTY" 2>/dev/null || true; }

log "Creating worktree (branch: $BRANCH)..."

# --- Create the git worktree ---
# IMPORTANT: redirect git output away from stdout — Claude parses stdout for the path
mkdir -p "${REPO_PATH}/.claude/worktrees"
if [ -d "$WORKTREE_PATH" ]; then
  # Worktree already exists — reuse it
  log "  Reusing existing worktree at $WORKTREE_PATH"
elif git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
  # Branch exists but no worktree directory — attach to existing branch
  git worktree add "$WORKTREE_PATH" "$BRANCH" >/dev/null 2>&1
else
  # Fresh: create new branch and worktree
  git worktree add -b "$BRANCH" "$WORKTREE_PATH" HEAD >/dev/null 2>&1
fi

# --- Read config and run setup ---
LOGFILE="${WORKTREE_PATH}/.worktree-setup.log"
SETUP_ERRORS=()

if [ -f "$CONFIG" ]; then
  # Copy files/directories listed under 'copy'
  COPY_COUNT=$(yq '.copy | length // 0' "$CONFIG" 2>/dev/null || echo 0)
  if [ "$COPY_COUNT" -gt 0 ]; then
    log "  Copying files..."
    for i in $(seq 0 $(( COPY_COUNT - 1 ))); do
      entry=$(yq -r ".copy[$i]" "$CONFIG")
      src="${REPO_PATH}/${entry}"
      dst="${WORKTREE_PATH}/${entry}"
      if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -R "$src/" "$dst/"
        log "    $entry/ (dir)"
      elif [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        log "    $entry"
      else
        log "    $entry (skipped, not found)"
      fi
    done
  fi

  # Run commands listed under 'setup'
  SETUP_COUNT=$(yq '.setup | length // 0' "$CONFIG" 2>/dev/null || echo 0)
  if [ "$SETUP_COUNT" -gt 0 ]; then
    for i in $(seq 0 $(( SETUP_COUNT - 1 ))); do
      cmd=$(yq -r ".setup[$i]" "$CONFIG")
      log "  Running: $cmd"
      (cd "${WORKTREE_PATH}" && eval "$cmd") >> "$LOGFILE" 2>&1 || SETUP_ERRORS+=("'$cmd' failed")
    done
  fi
else
  log "  No .worktree.yml found, skipping setup."
fi

# --- Done ---
if [ ${#SETUP_ERRORS[@]} -gt 0 ]; then
  log "Setup completed with errors:"
  printf '  - %s\n' "${SETUP_ERRORS[@]}" > "$TTY" 2>/dev/null || true
  log "See $LOGFILE for details."
else
  log "Worktree ready."
fi

# Tell Claude where the worktree is — THE ONLY THING ON STDOUT
echo "$WORKTREE_PATH"
