#!/bin/bash
# stop-unlock.sh - プロンプト処理完了時に全ロックを解放
#
# Stop Hook として使用。Claudeがプロンプトの処理を終えて停止する際に呼び出される。
# セッション中に取得した全ファイルロックを解放する。

if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  CLAUDE_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi
if [ -z "$CLAUDE_PROJECT_DIR" ]; then exit 0; fi

LOCK_DIR="$CLAUDE_PROJECT_DIR/.claude/cache/file-locks"
if [ ! -d "$LOCK_DIR" ]; then exit 0; fi

source "$CLAUDE_PROJECT_DIR/.claude/lib/file-lock.sh"
release_all_session_locks
