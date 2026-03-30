#!/bin/bash
# session-end-cleanup.sh - セッション終了時に全ロックを解放
#
# 配置先: .claude/hooks/scripts/session-end-cleanup.sh

if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  CLAUDE_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi
if [ -z "$CLAUDE_PROJECT_DIR" ]; then exit 0; fi

source "$CLAUDE_PROJECT_DIR/.claude/lib/file-lock.sh"
release_all_session_locks
