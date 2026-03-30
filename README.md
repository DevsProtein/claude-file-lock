# claude-file-lock

Claude Codeの並列セッションで、同じファイルの同時編集による競合を防止するHookスクリプトです。

## 何ができるか

- セッションAが編集中のファイル → セッションBが編集しようとするとブロック → 1分後に自動で再試行
- プロンプトの処理が完了したら自動でロック解放（Stop Hook）
- セッション終了時にも全ロックを自動解放
- プロセスが異常終了しても、stale検知で自動解放
- 30分経過で自動タイムアウト

## 前提条件

- `jq` コマンド（macOS: `brew install jq` / Linux: `apt install jq`）
- Git リポジトリ内のプロジェクト

## ファイル構成

```
あなたのプロジェクト/
└── .claude/
    ├── settings.json                      ← Hook設定（既存の場合はマージ）
    ├── hooks/
    │   └── scripts/
    │       ├── pretooluse-file-lock.sh    ← 編集前にロック取得
    │       ├── stop-unlock.sh             ← プロンプト処理完了時にロック解放
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

# settings.json をコピー（既存がある場合はhooksセクションをマージ）
cp claude-file-lock/.claude/settings.json .claude/settings.json

# スクリプトをコピー
cp claude-file-lock/.claude/lib/file-lock.sh .claude/lib/
cp claude-file-lock/.claude/hooks/scripts/*.sh .claude/hooks/scripts/
```

### 方法3: ワンライナー

```bash
git clone https://github.com/DevsProtein/claude-file-lock.git /tmp/claude-file-lock && \
  mkdir -p .claude/hooks/scripts .claude/lib && \
  cp /tmp/claude-file-lock/.claude/settings.json .claude/ && \
  cp /tmp/claude-file-lock/.claude/lib/file-lock.sh .claude/lib/ && \
  cp /tmp/claude-file-lock/.claude/hooks/scripts/*.sh .claude/hooks/scripts/ && \
  rm -rf /tmp/claude-file-lock
```

※ 実行権限（`chmod +x`）は不要です。settings.jsonが `bash <ファイル>` で呼び出すため、読み取り権限があれば動きます。

## 仕組み

1. **ファイル編集前（PreToolUse）** → ロックを取得。他セッションが編集中ならブロックし、1分後に再試行を指示
2. **プロンプト処理完了時（Stop）** → このセッションの全ロックを解放
3. **セッション開始時（SessionStart）** → 古いロック（プロセスが死んでいるもの）を掃除
4. **セッション終了時（SessionEnd）** → このセッションの全ロックを解放

ロックはプロンプトの処理が完了するまで保持されます。Claudeが複数ファイルにまたがる編集を行っている間、他セッションからの割り込みを防ぎます。

## 安全装置

- プロンプト処理完了時に自動でロック解放
- セッション終了時に全ロック解放
- プロセスが死んでいたら自動でロック解放（stale検知）
- 30分経過で自動解放（タイムアウト）

## 注意事項

- `.claude/settings.json` が既に存在する場合は、`hooks` セクションの内容をマージしてください
- `.claude/cache/file-locks/` にロックファイルが作成されます（`.gitignore` に追加推奨）

## License

MIT
