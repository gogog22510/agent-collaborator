#!/usr/bin/env bash
# Universal Claude Code Review Script with Graceful Fallback
# Usage: ./claude_review.sh [BASE_REF] [TASK_DESCRIPTION]

set -uo pipefail

BASE_REF="${1:-HEAD}"
TASK_DESC="${2:-未提供具體任務描述}"

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

DIFF_OUTPUT=$(git diff "$BASE_REF" 2>/dev/null || echo "")

if [ -z "$DIFF_OUTPUT" ]; then
  DIFF_OUTPUT=$(git diff HEAD~1 2>/dev/null || git show -p HEAD 2>/dev/null || echo "")
fi

DIFF_SNIPPET=$(echo "$DIFF_OUTPUT" | head -n 400)

PROMPT="你是一位資深的首席代碼審查員（Chief Code Reviewer）。
請對以下程式碼變更進行客觀、深度、且具體可落地的嚴格 Code Review。
語言要求：請永遠使用繁體中文回覆。

$PROJECT_HINT

【變更背景與目標】
$TASK_DESC

【Git Diff 變更內容】
$DIFF_SNIPPET

請提供結構化審查報告，格式如下：
### 1. 審查摘要 (Overview)
- 變更是否精準契合目標？架構與抽象層次是否乾淨？

### 2. 重大問題 (Critical / Blocker Issues)
- 任何潛在的 Crash、邏輯漏洞、回歸風險（Regression）、狀態脫鉤、並行 Race Condition、記憶體洩漏或安全漏洞。若無則寫「無」。

### 3. 改進建議 (Important / Minor Improvements)
- 效能優化、異常防護、測試覆蓋度或符合該語言最佳實踐的慣用語法建議。

### 4. 審查結論 (Verdict)
- [通過 / 需修改後通過 / 建議重新設計]
"

TEMP_OUTPUT=$(mktemp)
TEMP_ERR=$(mktemp)

echo "$PROMPT" | claude --safe-mode -p --tools "" > "$TEMP_OUTPUT" 2> "$TEMP_ERR"
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
