#!/usr/bin/env bash
# Universal Installer for claude-collaborator skill
# Usage:
#   ./install.sh           # Installs globally to ~/.gemini/config/skills/claude-collaborator
#   ./install.sh --local   # Installs into current project's .agent/skills/claude-collaborator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/skills/claude-collaborator"

MODE="${1:---global}"

if [ "$MODE" == "--local" ]; then
  TARGET_DIR="$(pwd)/.agent/skills/claude-collaborator"
  echo "🚀 Installing claude-collaborator locally to: $TARGET_DIR"
else
  TARGET_DIR="$HOME/.gemini/config/skills/claude-collaborator"
  echo "🚀 Installing claude-collaborator globally to: $TARGET_DIR"
fi

mkdir -p "$TARGET_DIR/scripts"
cp "$SKILL_SOURCE/SKILL.md" "$TARGET_DIR/"
cp "$SKILL_SOURCE/scripts/"*.sh "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/"*.sh

echo "✅ claude-collaborator successfully installed to: $TARGET_DIR"
echo ""
echo "💡 Quick verification:"
echo "   $TARGET_DIR/scripts/claude_design.sh \"測試連線\""
