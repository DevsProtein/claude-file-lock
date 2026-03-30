# claude-file-lock

Claude Codeの並列セッションで、同じファイルの同時編集による競合を防止するHookスクリプトです。

## 何ができるか

- セッションAがファイルを編集中 → セッションBが同じファイルを編集しようとするとブロック
- セッション終了時にロックを自動解放
- プロセスが異常終了しても、stale検知で自動解放
- 1時間経過で自動タイムアウト

## 前提条件

- `jq` コマンド（macOS: `brew install jq` / Linux: `apt install jq`）
- Git リポジトリ内のプロジェクト

## ファイル構成

```
あなたのプロジェクト/
└── .claude/
    ├── hooks/
    │   ├── hooks.json                     ← Hook設定
    │   └── scripts/
    │       ├── pretooluse-file-lock.sh    ← 編集前にロック取得
    │       ├── posttooluse-file-unlock.sh ← 編集後にロック解放
    │       ├── session-start-cleanup.sh   ← セッション開始時に古いロックを掃除
    │       └── session-end-cleanup.sh     ← セッション終了時に全ロック解放
    └── lib/
        └── file-lock.sh                   ← ロック管理の本体
```

## 導入方法

### 方法1: Claude Codeに導入させる（推奨）

このリポジトリの内容をClaude Codeに見せて「これを自分のプロジェクトに導入して」と言えば、適切な場所に全部配置してくれます。

### 方法2: 手動でコピー

```bash
# このリポジトリをクローン
git clone https://github.com/DevsProtein/claude-file-lock.git

# プロジェクトのルートで実行
mkdir -p .claude/hooks/scripts .claude/lib

# hooks.json をコピー（既存がある場合はマージが必要）
cp claude-file-lock/.claude/hooks/hooks.json .claude/hooks/hooks.json

# スクリプトをコピー
cp claude-file-lock/.claude/lib/file-lock.sh .claude/lib/
cp claude-file-lock/.claude/hooks/scripts/*.sh .claude/hooks/scripts/
```

### 方法3: ワンライナー

```bash
git clone https://github.com/DevsProtein/claude-file-lock.git /tmp/claude-file-lock && \
  mkdir -p .claude/hooks/scripts .claude/lib && \
  cp /tmp/claude-file-lock/.claude/hooks/hooks.json .claude/hooks/ && \
  cp /tmp/claude-file-lock/.claude/lib/file-lock.sh .claude/lib/ && \
  cp /tmp/claude-file-lock/.claude/hooks/scripts/*.sh .claude/hooks/scripts/ && \
  rm -rf /tmp/claude-file-lock
```

※ 実行権限（`chmod +x`）は不要です。hooks.jsonが `bash <ファイル>` で呼び出すため、読み取り権限があれば動きます。

## 仕組み

1. **ファイル編集前（PreToolUse）** → ロックを取得。他セッションが編集中ならブロック
2. **ファイル編集後（PostToolUse）** → ロックを解放
3. **セッション開始時（SessionStart）** → 古いロック（プロセスが死んでいるもの）を掃除
4. **セッション終了時（SessionEnd）** → このセッションの全ロックを解放

## 安全装置

- セッション終了時に自動でロック解放
- プロセスが死んでいたら自動でロック解放（stale検知）
- 1時間経過で自動解放（タイムアウト）

## 注意事項

- `hooks.json` が既に存在する場合は、内容をマージしてください
- `.claude/cache/file-locks/` にロックファイルが作成されます（`.gitignore` に追加推奨）

## License

MIT
