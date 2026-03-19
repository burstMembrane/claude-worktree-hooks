#!/usr/bin/env bash
# Claude Code WorktreeRemove hook — cleans up when a worktree is deleted.
#
# Contract:
#   - Receives JSON on stdin with 'worktree_path' field
#   - Exit 0 = success
#
# Dependencies: jq
set -euo pipefail

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path')

[ ! -d "$WORKTREE_PATH" ] && exit 0

# Remove the git worktree and delete worktree-specific branches
BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
if [ -n "$BRANCH" ] && [[ "$BRANCH" == worktree-* ]]; then
  git branch -D "$BRANCH" 2>/dev/null || true
fi
