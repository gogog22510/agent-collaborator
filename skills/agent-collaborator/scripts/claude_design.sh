#!/usr/bin/env bash
# Universal Claude Architecture & Design Script with Graceful Fallback
# Usage: ./claude_design.sh "<TASK_OR_REQUIREMENT>" [FILE_PATHS...]

set -uo pipefail

REQUIREMENT="${1:-}"
if [ -z "$REQUIREMENT" ]; then
  echo "Error: Missing requirement prompt." >&2
  echo "Usage: $0 \"<TASK_OR_REQUIREMENT>\" [FILE_PATHS...]" >&2
  exit 1
fi
shift

PROJECT_HINT=""
if [ -f "pubspec.yaml" ]; then
  PROJECT_HINT="專案技術棧：Dart / Flutter"
elif [ -f "package.json" ]; then
  PROJECT_HINT="專案技術棧：Node.js / TypeScript / JavaScript"
elif [ -f "Cargo.toml" ]; then
  PROJECT_HINT="專案技術棧：Rust"
elif [ -f "go.mod" ]; then
  PROJECT_HINT="專案技術棧：Go"
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  PROJECT_HINT="專案技術棧：Python"
fi

FILE_CONTEXT=""
for f in "$@"; do
  if [ -f "$f" ]; then
    FILE_CONTEXT+=$'\n\n'"--- File: $f ---"$'\n'
    FILE_CONTEXT+="$(cat "$f")"
  fi
done

PROMPT="你是一位精通軟體架構、系統設計與演算法的資深架構師。
語言要求：請永遠使用繁體中文回覆。

$PROJECT_HINT

【設計目標與需求】
$REQUIREMENT

【相關上下文檔案】
$FILE_CONTEXT

請提供結構清晰、可直接落地指導實作的架構設計方案，包含：
1. 核心設計架構與資料流向 / 狀態管理
2. 關鍵邊界條件、異常處理、並發安全與潛在陷阱
3. 模組介面定義 (API / Interface / Types) 與關鍵演算法虛擬碼
4. 推薦的實作步驟順序與單元測試建議
"

# 執行 Claude CLI 並捕捉輸出與錯誤
TEMP_OUTPUT=$(mktemp)
TEMP_ERR=$(mktemp)

echo "$PROMPT" | claude -p --tools "" > "$TEMP_OUTPUT" 2> "$TEMP_ERR"
EXIT_CODE=$?

OUTPUT_STR=$(cat "$TEMP_OUTPUT")
ERR_STR=$(cat "$TEMP_ERR")
rm -f "$TEMP_OUTPUT" "$TEMP_ERR"

# 偵測是否觸發 Usage Limit、Rate Limit 或連線失敗
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT_STR $ERR_STR" | grep -qiE "(rate limit|usage limit|quota|exceeded|credit balance|overloaded|429|529|authentication)"; then
  echo "⚠️ [FALLBACK_TRIGGERED: CLAUDE_UNAVAILABLE]"
  echo "Reason: Claude CLI usage limit or connection error detected (Exit: $EXIT_CODE)."
  if [ -n "$ERR_STR" ]; then
    echo "Detail: $ERR_STR"
  fi
  exit 100
fi

echo "$OUTPUT_STR"
exit 0
