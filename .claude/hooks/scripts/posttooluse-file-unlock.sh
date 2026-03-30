#!/bin/bash
# posttooluse-file-unlock.sh - 編集後にファイルロックを解放
#
# 配置先: .claude/hooks/scripts/posttooluse-file-unlock.sh

set -e

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "MultiEdit" ]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [ -z "$FILE_PATH" ]; then exit 0; fi

if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  CLAUDE_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
fi
if [ -z "$CLAUDE_PROJECT_DIR" ]; then exit 0; fi

source "$CLAUDE_PROJECT_DIR/.claude/lib/file-lock.sh"

REL_PATH="$FILE_PATH"
if [[ "$FILE_PATH" == "$CLAUDE_PROJECT_DIR"* ]]; then
  REL_PATH="${FILE_PATH#$CLAUDE_PROJECT_DIR/}"
fi

release_lock "$REL_PATH" 2>/dev/null || true
