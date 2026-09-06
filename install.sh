#!/usr/bin/env bash
# ==============================================================================
# Universal Modular Installer for agent-collaborator (Claude / Codex / Cursor)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR/skills/agent-collaborator"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

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
  ln -sf "$SKILL_SRC/scripts/codex_optimize.sh" "$BIN_DIR/codex-optimize"
  rm -f "$BIN_DIR/claude-prompt-tune" 2>/dev/null || true

  chmod +x "$BIN_DIR/claude-design" "$BIN_DIR/claude-review" "$BIN_DIR/claude-refine" "$BIN_DIR/codex-optimize"
  echo -e "${GREEN}✓ CLI tools linked:${NC}"
  echo "    - $BIN_DIR/claude-design"
  echo "    - $BIN_DIR/claude-review"
  echo "    - $BIN_DIR/claude-refine"
  echo "    - $BIN_DIR/codex-optimize"
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

  # Synchronize global AGENTS.md multi-agent verification protocol
  local PROTOCOL_FILE="$SCRIPT_DIR/templates/AGENTS.md"
  if [ -f "$PROTOCOL_FILE" ]; then
    if python3 - "$PROTOCOL_FILE" "$HOME" <<'EOF'
import sys, os, re

template_path = sys.argv[1]
home_dir = sys.argv[2]

with open(template_path, "r", encoding="utf-8") as f:
    text = f.read()

# Extract content between ```markdown and ``` code fences if present, otherwise whole text
match = re.search(r"```markdown\n(.*?)\n```", text, re.DOTALL)
content = match.group(1).strip() + "\n" if match else text

targets = [
    os.path.join(home_dir, ".gemini", "config", "AGENTS.md"),
    os.path.join(home_dir, ".gemini", "AGENTS.md"),
]
for target in targets:
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as out:
        out.write(content)
EOF
    then
      echo -e "${GREEN}✓ Updated global AGENTS.md in ~/.gemini/config and ~/.gemini${NC}"
    else
      echo -e "${YELLOW}⚠ Failed to synchronize global AGENTS.md${NC}"
    fi
  fi
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

  # Check for project-local Superpowers duplicates that might shadow global plugins
  local STALE_SKILLS=("using-superpowers" "brainstorming" "systematic-debugging" "test-driven-development" "executing-plans" "writing-plans" "verification-before-completion" "finishing-a-development-branch" "receiving-code-review" "requesting-code-review")
  local found_stale=false
  for s in "${STALE_SKILLS[@]}"; do
    if [ -d "$TARGET_DIR/.agent/skills/$s" ]; then
      found_stale=true
      break
    fi
  done
  if [ "$found_stale" = true ]; then
    echo -e "${YELLOW}  ⚠ Notice: Detected project-local skills in $TARGET_DIR/.agent/skills/${NC}"
    echo "    (Project-local skills take precedence and may shadow newer global Superpowers plugin updates)."
    if [ -t 0 ]; then
      read -rp "    Back up and remove local duplicate skills to use global plugin? [y/N] " clean_ans
      if [[ "$clean_ans" =~ ^[Yy]$ ]]; then
        local BACKUP_DIR="$TARGET_DIR/.agent/skills.backup-$(date +%Y%m%d%H%M%S)_$$"
        mkdir -p "$BACKUP_DIR"
        for s in "${STALE_SKILLS[@]}"; do
          if [ -d "$TARGET_DIR/.agent/skills/$s" ]; then
            mv "$TARGET_DIR/.agent/skills/$s" "$BACKUP_DIR/"
          fi
        done
        echo -e "${GREEN}    ✓ Moved local duplicate skills to backup: $BACKUP_DIR${NC}"
      fi
    else
      echo "    To use global plugin updates, remove or rename local duplicate skills when ready."
    fi
  fi

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

AGENTS_MD_MARKER_START="<!-- agent-collaborator:protocol:start -->"
AGENTS_MD_MARKER_END="<!-- agent-collaborator:protocol:end -->"

# Injects or updates (idempotently and safely) the Multi-Agent Peer Collaboration Protocol
# into a single target file using in-place marker-bounded replacement.
inject_into_single_file() {
  local TARGET_FILE="$1"
  local TEMPLATE_FILE="$2"

  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${YELLOW}  ⚠ python3 not found on PATH. Cannot perform marker-scoped update for $TARGET_FILE.${NC}"
    return 1
  fi

  local py_out
  local py_err
  local py_status=0
  local tmp_err
  tmp_err="$(mktemp 2>/dev/null || echo "/tmp/inject_err_$$.txt")"

  py_out=$(python3 - "$TARGET_FILE" "$TEMPLATE_FILE" "$AGENTS_MD_MARKER_START" "$AGENTS_MD_MARKER_END" 2>"$tmp_err" <<'EOF'
import sys, os, re

agents_file = sys.argv[1]
template_file = sys.argv[2]
marker_start = sys.argv[3]
marker_end = sys.argv[4]

with open(template_file, "r", encoding="utf-8") as f:
    text = f.read()

match = re.search(r"```markdown\n(.*?)\n```", text, re.DOTALL)
contract = match.group(1).strip() + "\n" if match else text
block = f"{marker_start}\n{contract}{marker_end}\n"

if not os.path.exists(agents_file):
    parent_dir = os.path.dirname(os.path.abspath(agents_file))
    if parent_dir:
        os.makedirs(parent_dir, exist_ok=True)
    with open(agents_file, "w", encoding="utf-8") as f:
        f.write(block)
    print("INJECTED")
    sys.exit(0)

with open(agents_file, "r", encoding="utf-8") as f:
    existing = f.read()

pattern = re.escape(marker_start) + r".*?" + re.escape(marker_end) + r"\n?"
if re.search(pattern, existing, re.DOTALL):
    updated = re.sub(pattern, lambda m: block, existing, flags=re.DOTALL)
    with open(agents_file, "w", encoding="utf-8") as f:
        f.write(updated)
    print("UPDATED")
else:
    prefix = "\n" if existing.strip() else ""
    with open(agents_file, "w", encoding="utf-8") as f:
        f.write(existing + prefix + block)
    print("INJECTED")
EOF
) || py_status=$?

  py_err="$(cat "$tmp_err" 2>/dev/null || true)"
  rm -f "$tmp_err"

  if [ $py_status -ne 0 ]; then
    echo -e "${YELLOW}  ⚠ Python injection failed ($py_status): $py_err${NC}"
    return 1
  fi

  if [ "$py_out" = "UPDATED" ]; then
    echo -e "${GREEN}✓ Updated Multi-Agent Peer Collaboration Protocol in $TARGET_FILE (in-place)${NC}"
  elif [ "$py_out" = "INJECTED" ]; then
    echo -e "${GREEN}✓ Injected Multi-Agent Peer Collaboration Protocol into $TARGET_FILE${NC}"
  fi
  return 0
}

# Injects or updates (idempotently) the Multi-Agent Peer Collaboration Protocol from
# templates/AGENTS.md into the target project's AGENTS.md and .agent/AGENTS.md (if present).
inject_agents_md() {
  local TARGET_DIR="${1:-$(pwd)}"
  local AGENTS_FILE="$TARGET_DIR/AGENTS.md"
  local TEMPLATE_FILE="$TEMPLATE_DIR/AGENTS.md"

  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${YELLOW}  ⚠ Template file $TEMPLATE_FILE not found, skipping injection.${NC}"
    return
  fi

  inject_into_single_file "$AGENTS_FILE" "$TEMPLATE_FILE"

  # If .agent directory exists, also update .agent/AGENTS.md via marker-scoped replacement (never blind cp)
  if [ -d "$TARGET_DIR/.agent" ]; then
    local DOT_AGENT_FILE="$TARGET_DIR/.agent/AGENTS.md"
    if [ "$DOT_AGENT_FILE" != "$AGENTS_FILE" ] && [ -f "$DOT_AGENT_FILE" ]; then
      inject_into_single_file "$DOT_AGENT_FILE" "$TEMPLATE_FILE"
    fi
  fi
}

# Attempts to install the Superpowers methodology plugin (obra/superpowers)
# non-interactively for whichever driver CLI is detected on PATH. Superpowers
# itself is a separate project from agent-collaborator; this only automates
# the install step documented in the README.
install_superpowers() {
  echo -e "\n${BLUE}▶ Installing Superpowers methodology plugin...${NC}"
  local installed_any=false

  if command -v agy >/dev/null 2>&1; then
    echo "  Detected Antigravity CLI (agy). Installing Superpowers plugin..."
    if agy plugin install https://github.com/obra/superpowers; then
      echo -e "${GREEN}  ✓ Superpowers installed for Antigravity.${NC}"
      installed_any=true
    else
      echo -e "${YELLOW}  ⚠ 'agy plugin install' failed. See manual fallback below.${NC}"
    fi
  fi

  if command -v claude >/dev/null 2>&1; then
    echo "  Detected Claude Code CLI. Installing Superpowers from the official marketplace..."
    if claude plugin install superpowers@claude-plugins-official >/dev/null 2>&1; then
      echo -e "${GREEN}  ✓ Superpowers installed for Claude Code.${NC}"
      installed_any=true
    else
      echo -e "${YELLOW}  ⚠ Non-interactive 'claude plugin install' failed (this Claude Code version may only support it inside an interactive session).${NC}"
      echo "    Run this manually inside a Claude Code session instead:"
      echo "      /plugin install superpowers@claude-plugins-official"
    fi
  fi

  if [ "$installed_any" = false ]; then
    echo -e "${YELLOW}  ⚠ Neither 'agy' nor 'claude' CLI was found on PATH (or both failed).${NC}"
    echo "  Install manually depending on your driver:"
    echo "    Antigravity: agy plugin install https://github.com/obra/superpowers"
    echo "                 (or clone into ~/.gemini/config/plugins/superpowers)"
    echo "    Claude Code: /plugin install superpowers@claude-plugins-official"
    echo "    Cursor:      /add-plugin superpowers"
  fi
}

show_menu() {
  print_banner
  echo "Select an installation target:"
  echo "  1) All (CLI Tools + Antigravity Global + Claude Code Global) [Recommended]"
  echo "  2) Standalone CLI Tools only (~/.local/bin/claude-design, ...)"
  echo "  3) Antigravity Global Skills (~/.gemini/...)"
  echo "  4) Project-Local Skill (.agent/skills/ in current directory)"
  echo "  5) Claude Code Global Skills (~/.claude/skills/)"
  echo "  6) Install Superpowers methodology plugin (Antigravity / Claude Code)"
  echo "  q) Quit"
  echo ""
  read -rp "Enter choice [1-6]: " choice
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
      read -rp "Inject the Multi-Agent Peer Collaboration Protocol into $(pwd)/AGENTS.md? [Y/n] " ans
      if [[ ! "$ans" =~ ^[Nn]$ ]]; then
        inject_agents_md "$(pwd)"
      fi
      ;;
    5)
      install_claude_code_global
      ;;
    6)
      install_superpowers
      ;;
    *)
      echo "Installation cancelled."
      exit 0
      ;;
  esac
}

# Pre-scan for flags that can combine with any action below, so e.g.
# `./install.sh --project . --with-superpowers` works in one shot.
WITH_SUPERPOWERS=false
INJECT_AGENTS_MD=true
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --with-superpowers) WITH_SUPERPOWERS=true ;;
    --no-agents-md) INJECT_AGENTS_MD=false ;;
    *) ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# CLI Argument parsing
if [ $# -eq 0 ]; then
  if [ "$WITH_SUPERPOWERS" = true ]; then
    print_banner
    install_superpowers
  elif [ -t 0 ]; then
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
      if [ "$INJECT_AGENTS_MD" = true ]; then
        inject_agents_md "$TARGET_PATH"
      fi
      ;;
    --help|-h)
      echo "Usage: ./install.sh [OPTION] [--with-superpowers] [--no-agents-md]"
      echo "Options:"
      echo "  --all                 Install CLI tools, Antigravity global, and Claude Code skills"
      echo "  --cli                 Install standalone CLI tools to ~/.local/bin"
      echo "  --antigravity-global  Install to ~/.gemini/skills and ~/.gemini/config/skills"
      echo "  --claude-code         Install to ~/.claude/skills"
      echo "  --project [PATH]      Install locally to [PATH]/.agent/skills and .claude/skills"
      echo "                        (also injects the collaboration protocol into [PATH]/AGENTS.md)"
      echo "  --with-superpowers    Also install the Superpowers methodology plugin (obra/superpowers)"
      echo "                        for whichever of agy/claude is found on PATH. Can combine with"
      echo "                        any option above, or be used standalone."
      echo "  --no-agents-md        With --project, skip injecting the protocol into AGENTS.md"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      echo -e "${YELLOW}Unknown option: $1${NC}"
      echo "Run './install.sh --help' for usage."
      exit 1
      ;;
  esac

  if [ "$WITH_SUPERPOWERS" = true ]; then
    install_superpowers
  fi
fi

echo -e "\n${GREEN}🎉 Installation completed successfully!${NC}\n"
