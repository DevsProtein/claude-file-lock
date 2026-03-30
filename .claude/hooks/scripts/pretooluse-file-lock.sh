#!/bin/bash
# pretooluse-file-lock.sh - 編集前にファイルロックを取得
#
# 配置先: .claude/hooks/scripts/pretooluse-file-lock.sh

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "MultiEdit" ]; then
  echo '{"decision": "approve", "reason": "not an edit tool"}'
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [ -z "$FILE_PATH" ]; then
  echo '{"decision": "approve", "reason": "no file path"}'
  exit 0
fi

# ロック不要なファイルを除外
case "$FILE_PATH" in
  *.lock|*node_modules/*|*/.claude/cache/*)
    echo '{"decision": "approve", "reason": "excluded"}'
    exit 0
    ;;
esac

if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  CLAUDE_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi
if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  echo '{"decision": "approve", "reason": "not in git repository"}'
  exit 0
fi

source "$CLAUDE_PROJECT_DIR/.claude/lib/file-lock.sh"

REL_PATH="$FILE_PATH"
if [[ "$FILE_PATH" == "$CLAUDE_PROJECT_DIR"* ]]; then
  REL_PATH="${FILE_PATH#$CLAUDE_PROJECT_DIR/}"
fi

set +e
LOCK_RESULT=$(acquire_lock "$REL_PATH" "$TOOL_NAME")
LOCK_STATUS=$?
set -e

if [ $LOCK_STATUS -eq 0 ]; then
  echo '{"decision": "approve", "reason": "lock acquired for '"$REL_PATH"'"}'
  exit 0
fi

# 競合検知 — ブロック（exit 2 でClaude Codeにツール実行を拒否させる）
CONFLICT_SESSION=$(echo "$LOCK_RESULT" | jq -r '.sessionId // "unknown"')
echo "⚠️ $REL_PATH は別のセッション ($CONFLICT_SESSION) が編集中です。Bashツールで「sleep 60」を実行してから、再度このファイルの編集を試みてください。" >&2
exit 2
