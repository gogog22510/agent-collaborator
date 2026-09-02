#!/usr/bin/env bash
# ==============================================================================
# Universal Modular Installer for agent-collaborator (Claude / Codex / Cursor)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR/skills/agent-collaborator"

# Color helpers
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

print_banner() {
  echo -e "${BLUE}======================================================${NC}"
  echo -e "${GREEN}  🤝 Agent Collaborator Universal Installer${NC}"
  echo -e "${BLUE}======================================================${NC}"
}

install_cli() {
  echo -e "\n${BLUE}▶ Installing Standalone CLI tools (~/.local/bin)...${NC}"
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"

  ln -sf "$SKILL_SRC/scripts/claude_design.sh" "$BIN_DIR/claude-design"
  ln -sf "$SKILL_SRC/scripts/claude_review.sh" "$BIN_DIR/claude-review"
  ln -sf "$SKILL_SRC/scripts/claude_refine.sh" "$BIN_DIR/claude-refine"
  ln -sf "$SKILL_SRC/scripts/claude_prompt_tune.sh" "$BIN_DIR/claude-prompt-tune"

  chmod +x "$BIN_DIR/claude-design" "$BIN_DIR/claude-review" "$BIN_DIR/claude-refine" "$BIN_DIR/claude-prompt-tune"
  echo -e "${GREEN}✓ CLI tools linked:${NC}"
  echo "    - $BIN_DIR/claude-design"
  echo "    - $BIN_DIR/claude-review"
  echo "    - $BIN_DIR/claude-refine"
  echo "    - $BIN_DIR/claude-prompt-tune"
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}  ⚠ Note: Ensure $BIN_DIR is in your PATH in ~/.zshrc or ~/.bashrc${NC}"
  fi
}

install_antigravity_global() {
  echo -e "\n${BLUE}▶ Installing to Antigravity Global Skills (~/.gemini)...${NC}"
  # Clean up legacy claude-collaborator global dirs if present
  rm -rf "$HOME/.gemini/config/skills/claude-collaborator" "$HOME/.gemini/skills/claude-collaborator" 2>/dev/null || true

  TARGET_PATHS=(
    "$HOME/.gemini/config/skills/agent-collaborator"
    "$HOME/.gemini/skills/agent-collaborator"
  )

  for T in "${TARGET_PATHS[@]}"; do
    mkdir -p "$T/scripts"
    cp "$SKILL_SRC/SKILL.md" "$T/"
    cp "$SKILL_SRC/scripts/"*.sh "$T/scripts/"
    chmod +x "$T/scripts/"*.sh
    echo -e "${GREEN}✓ Installed to $T${NC}"
  done
}

install_claude_code_global() {
  echo -e "\n${BLUE}▶ Installing to Claude Code Global Skills (~/.claude/skills)...${NC}"
  # Clean up legacy claude-collaborator dir if present
  rm -rf "$HOME/.claude/skills/claude-collaborator" 2>/dev/null || true

  TARGET="$HOME/.claude/skills/agent-collaborator"
  mkdir -p "$TARGET/scripts"
  cp "$SKILL_SRC/SKILL.md" "$TARGET/"
  cp "$SKILL_SRC/scripts/"*.sh "$TARGET/scripts/"
  chmod +x "$TARGET/scripts/"*.sh
  echo -e "${GREEN}✓ Installed to $TARGET${NC}"
}

install_project_local() {
  local TARGET_DIR="${1:-$(pwd)}"
  echo -e "\n${BLUE}▶ Installing Project-Local Skill into: $TARGET_DIR...${NC}"

  # Clean up legacy project-local claude-collaborator dir if present
  rm -rf "$TARGET_DIR/.agent/skills/claude-collaborator" 2>/dev/null || true

  # Support .agent/skills (Antigravity / Superpowers) and .claude/skills
  AGENT_TARGET="$TARGET_DIR/.agent/skills/agent-collaborator"
  CLAUDE_TARGET="$TARGET_DIR/.claude/skills/agent-collaborator"

  for D in "$AGENT_TARGET" "$CLAUDE_TARGET"; do
    mkdir -p "$D/scripts"
    cp "$SKILL_SRC/SKILL.md" "$D/"
    cp "$SKILL_SRC/scripts/"*.sh "$D/scripts/"
    chmod +x "$D/scripts/"*.sh
  done

  echo -e "${GREEN}✓ Local skills installed into $AGENT_TARGET and $CLAUDE_TARGET${NC}"
}

show_menu() {
  print_banner
  echo "Select an installation target:"
  echo "  1) All (CLI Tools + Antigravity Global + Claude Code Global) [Recommended]"
  echo "  2) Standalone CLI Tools only (~/.local/bin/claude-design, ...)"
  echo "  3) Antigravity Global Skills (~/.gemini/...)"
  echo "  4) Project-Local Skill (.agent/skills/ in current directory)"
  echo "  5) Claude Code Global Skills (~/.claude/skills/)"
  echo "  q) Quit"
  echo ""
  read -rp "Enter choice [1-5]: " choice
  case "$choice" in
    1)
      install_cli
      install_antigravity_global
      install_claude_code_global
      ;;
    2)
      install_cli
      ;;
    3)
      install_antigravity_global
      ;;
    4)
      install_project_local "$(pwd)"
      ;;
    5)
      install_claude_code_global
      ;;
    *)
      echo "Installation cancelled."
      exit 0
      ;;
  esac
}

# CLI Argument parsing
if [ $# -eq 0 ]; then
  if [ -t 0 ]; then
    show_menu
  else
    print_banner
    install_cli
    install_antigravity_global
    install_claude_code_global
  fi
else
  print_banner
  case "$1" in
    --all)
      install_cli
      install_antigravity_global
      install_claude_code_global
      ;;
    --cli)
      install_cli
      ;;
    --antigravity-global|--gemini|--global)
      install_antigravity_global
      ;;
    --claude-code)
      install_claude_code_global
      ;;
    --project|--local)
      TARGET_PATH="${2:-$(pwd)}"
      install_project_local "$TARGET_PATH"
      ;;
    --help|-h)
      echo "Usage: ./install.sh [OPTION]"
      echo "Options:"
      echo "  --all                 Install CLI tools, Antigravity global, and Claude Code skills"
      echo "  --cli                 Install standalone CLI tools to ~/.local/bin"
      echo "  --antigravity-global  Install to ~/.gemini/skills and ~/.gemini/config/skills"
      echo "  --claude-code         Install to ~/.claude/skills"
      echo "  --project [PATH]      Install locally to [PATH]/.agent/skills and .claude/skills"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      echo -e "${YELLOW}Unknown option: $1${NC}"
      echo "Run './install.sh --help' for usage."
      exit 1
      ;;
  esac
fi

echo -e "\n${GREEN}🎉 Installation completed successfully!${NC}\n"
