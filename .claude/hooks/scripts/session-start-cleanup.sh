#!/bin/bash
# session-start-cleanup.sh - セッション開始時に古いロックを掃除
#
# 配置先: .claude/hooks/scripts/session-start-cleanup.sh

if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  CLAUDE_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi
if [ -z "$CLAUDE_PROJECT_DIR" ]; then exit 0; fi

LOCK_DIR="$CLAUDE_PROJECT_DIR/.claude/cache/file-locks"
if [ -d "$LOCK_DIR" ]; then
  source "$CLAUDE_PROJECT_DIR/.claude/lib/file-lock.sh"
  cleaned=$(cleanup_stale_locks)
  if [ "$cleaned" -gt 0 ] 2>/dev/null; then
    echo "Cleaned up $cleaned stale lock(s)"
  fi
fi
