#!/bin/bash
# file-lock.sh - 並列セッション間のファイルロック管理
#
# 配置先: .claude/lib/file-lock.sh

if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  CLAUDE_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
fi

LOCK_DIR="$CLAUDE_PROJECT_DIR/.claude/cache/file-locks"
SESSION_DIR="$LOCK_DIR/sessions"
LOCK_TIMEOUT_SECONDS=3600  # 1時間でタイムアウト

get_session_id() {
  if [ -n "$CLAUDE_SESSION_ID" ]; then
    echo "$CLAUDE_SESSION_ID"
  elif [ -n "$PPID" ] && [ "$PPID" != "0" ] && [ "$PPID" != "1" ]; then
    echo "ppid${PPID}"
  else
    echo "pid$$_$(date +%Y%m%d%H%M%S)"
  fi
}

get_lock_filename() {
  local file_path="$1"
  if command -v md5 > /dev/null 2>&1; then
    echo "$file_path" | md5
  else
    echo "$file_path" | md5sum | awk '{print $1}'
  fi
}

get_lock_path() {
  local file_path="$1"
  local hash
  hash=$(get_lock_filename "$file_path")
  echo "$LOCK_DIR/${hash}.lock"
}

is_process_alive() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

is_lock_stale() {
  local lock_file="$1"
  if [ ! -f "$lock_file" ]; then return 0; fi

  local lock_pid lock_time
  lock_pid=$(jq -r '.pid' "$lock_file" 2>/dev/null)
  lock_time=$(jq -r '.lockedAt' "$lock_file" 2>/dev/null)

  # プロセスが死んでいたらstale
  if [ -n "$lock_pid" ] && [ "$lock_pid" != "null" ]; then
    if ! is_process_alive "$lock_pid"; then return 0; fi
  fi

  # タイムアウトチェック
  if [ -n "$lock_time" ] && [ "$lock_time" != "null" ]; then
    local lock_timestamp current_time elapsed
    lock_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${lock_time%+*}" "+%s" 2>/dev/null || \
                     date -d "$lock_time" "+%s" 2>/dev/null)
    current_time=$(date "+%s")
    if [ -n "$lock_timestamp" ]; then
      elapsed=$((current_time - lock_timestamp))
      if [ "$elapsed" -gt "$LOCK_TIMEOUT_SECONDS" ]; then return 0; fi
    fi
  fi

  return 1
}

acquire_lock() {
  local file_path="$1"
  local tool_name="${2:-Edit}"
  local lock_path session_id
  lock_path=$(get_lock_path "$file_path")
  session_id=$(get_session_id)

  mkdir -p "$LOCK_DIR" "$SESSION_DIR"

  if [ -f "$lock_path" ]; then
    local existing_session
    existing_session=$(jq -r '.sessionId' "$lock_path" 2>/dev/null)

    # 自分のセッションなら更新
    if [ "$existing_session" = "$session_id" ]; then
      local now
      now=$(date +"%Y-%m-%dT%H:%M:%S$(date +%z | sed 's/\(..\)$/:\1/')")
      jq --arg time "$now" '.lockedAt = $time' "$lock_path" > "${lock_path}.tmp" && \
        mv "${lock_path}.tmp" "$lock_path"
      echo '{"status": "updated", "file": "'"$file_path"'"}'
      return 0
    fi

    # 他セッションのロック → staleチェック
    if ! is_lock_stale "$lock_path"; then
      cat "$lock_path"
      return 1
    fi
    rm -f "$lock_path"
  fi

  # 新規ロック作成
  local now lock_pid
  now=$(date +"%Y-%m-%dT%H:%M:%S$(date +%z | sed 's/\(..\)$/:\1/')")
  lock_pid="${PPID:-$$}"

  cat > "$lock_path" << EOF
{
  "file": "$file_path",
  "sessionId": "$session_id",
  "pid": $lock_pid,
  "lockedAt": "$now",
  "tool": "$tool_name"
}
EOF

  echo '{"status": "acquired", "file": "'"$file_path"'"}'
  return 0
}

release_lock() {
  local file_path="$1"
  local lock_path session_id
  lock_path=$(get_lock_path "$file_path")
  session_id=$(get_session_id)

  if [ ! -f "$lock_path" ]; then return 0; fi

  local existing_session
  existing_session=$(jq -r '.sessionId' "$lock_path" 2>/dev/null)
  if [ "$existing_session" = "$session_id" ]; then
    rm -f "$lock_path"
    return 0
  fi
  return 1
}

release_all_session_locks() {
  local session_id
  session_id=$(get_session_id)

  for lock_file in "$LOCK_DIR"/*.lock; do
    if [ -f "$lock_file" ]; then
      local lock_session
      lock_session=$(jq -r '.sessionId' "$lock_file" 2>/dev/null)
      if [ "$lock_session" = "$session_id" ]; then
        rm -f "$lock_file"
      fi
    fi
  done
  rm -f "$SESSION_DIR/${session_id}.json"
}

cleanup_stale_locks() {
  local cleaned=0
  for lock_file in "$LOCK_DIR"/*.lock; do
    if [ -f "$lock_file" ] && is_lock_stale "$lock_file"; then
      rm -f "$lock_file"
      ((cleaned++))
    fi
  done
  echo "$cleaned"
}
