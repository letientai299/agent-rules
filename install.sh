#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/.ai.dump/backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
TARGET_HOME="$HOME"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -t, --target DIR   Install to DIR instead of \$HOME (for verification)
  -n, --dry-run      Show what would be done without making changes
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--target)
      TARGET_HOME="$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}✗${NC} Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}Dry run mode — no changes will be made.${NC}"
  echo
fi

if [[ "$TARGET_HOME" != "$HOME" ]]; then
  echo -e "${YELLOW}Target: ${BOLD}$TARGET_HOME${NC} (instead of \$HOME)"
  echo
fi

log()  { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

backup_and_link() {
  local source="$1"
  local target="$2"
  local label="$3"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -e "$target" || -L "$target" ]]; then
      info "[dry-run] Would backup $target → $BACKUP_DIR/"
    fi
    info "[dry-run] Would symlink $target → $source"
    return
  fi

  # Backup existing target
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$target")"
    # Preserve directory structure in backup
    local parent_label="${label//\//-}"
    cp -RL "$target" "$BACKUP_DIR/${parent_label}-${backup_name}" 2>/dev/null || \
      cp -R "$target" "$BACKUP_DIR/${parent_label}-${backup_name}" 2>/dev/null || true
    warn "Backed up $target → $BACKUP_DIR/${parent_label}-${backup_name}"
    rm -rf "$target"
  fi

  # Create parent directory if needed
  mkdir -p "$(dirname "$target")"

  # Create symlink
  ln -sfn "$source" "$target"
  log "$label: $target → $source"
}

echo -e "${BOLD}Agent Rules Installer${NC}"
echo -e "Source: ${BLUE}$SCRIPT_DIR${NC}"
echo

# ── Shared (canonical path for all agents) ───────────────────────────────────
echo -e "${BOLD}Shared Rules${NC}"
backup_and_link "$SCRIPT_DIR" "$TARGET_HOME/.agent-rules" "shared"
echo

# ── Claude Code ──────────────────────────────────────────────────────────────
echo -e "${BOLD}Claude Code${NC}"

# We symlink individual directories/files inside ~/.claude rather than the
# whole directory, because ~/.claude also contains session state, projects/,
# auto-generated files we don't want in our repo.

mkdir -p "$TARGET_HOME/.claude"

backup_and_link "$SCRIPT_DIR/claude/CLAUDE.md"      "$TARGET_HOME/.claude/CLAUDE.md"       "claude"
backup_and_link "$SCRIPT_DIR/claude/rules"           "$TARGET_HOME/.claude/rules"           "claude"
backup_and_link "$SCRIPT_DIR/claude/hooks"           "$TARGET_HOME/.claude/hooks"           "claude"
backup_and_link "$SCRIPT_DIR/claude/settings.json"   "$TARGET_HOME/.claude/settings.json"   "claude"
echo

# ── Codex (OpenAI) ──────────────────────────────────────────────────────────
echo -e "${BOLD}Codex${NC}"
backup_and_link "$SCRIPT_DIR/codex/AGENTS.md" "$TARGET_HOME/.codex/AGENTS.md" "codex"
echo

# ── GitHub Copilot ───────────────────────────────────────────────────────────
echo -e "${BOLD}GitHub Copilot${NC}"
backup_and_link "$SCRIPT_DIR/copilot/copilot-instructions.md" \
  "$TARGET_HOME/.copilot/copilot-instructions.md" "copilot"
echo

# ── Gemini CLI ───────────────────────────────────────────────────────────────
echo -e "${BOLD}Gemini CLI${NC}"
backup_and_link "$SCRIPT_DIR/gemini/GEMINI.md"       "$TARGET_HOME/.gemini/GEMINI.md"       "gemini"
backup_and_link "$SCRIPT_DIR/gemini/settings.json"   "$TARGET_HOME/.gemini/settings.json"   "gemini"
echo

# ── Global gitignore ─────────────────────────────────────────────────────────
echo -e "${BOLD}Global gitignore${NC}"

GITIGNORE="$TARGET_HOME/.gitignore"
GITIGNORE_ENTRY=".ai.dump/"

if [[ "$TARGET_HOME" != "$HOME" ]]; then
  # When targeting a custom dir, just create the gitignore file there
  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Would create $GITIGNORE with '$GITIGNORE_ENTRY'"
  else
    if ! grep -qxF "$GITIGNORE_ENTRY" "$GITIGNORE" 2>/dev/null; then
      echo "$GITIGNORE_ENTRY" >> "$GITIGNORE"
      log "Added '$GITIGNORE_ENTRY' to $GITIGNORE"
    else
      log ".ai.dump/ already in $GITIGNORE"
    fi
  fi
else
  # Real install — also configure git core.excludesFile
  CURRENT_EXCLUDES=$(git config --global core.excludesFile 2>/dev/null || echo "")
  # Expand ~ to $HOME (git config may store literal tilde)
  CURRENT_EXCLUDES="${CURRENT_EXCLUDES/#\~/$HOME}"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -z "$CURRENT_EXCLUDES" ]]; then
      info "[dry-run] Would set git core.excludesFile → $GITIGNORE"
    fi
    if ! grep -qxF "$GITIGNORE_ENTRY" "$GITIGNORE" 2>/dev/null; then
      info "[dry-run] Would add '$GITIGNORE_ENTRY' to $GITIGNORE"
    else
      log ".ai.dump/ already in $GITIGNORE"
    fi
  else
    if [[ -z "$CURRENT_EXCLUDES" ]]; then
      git config --global core.excludesFile "$GITIGNORE"
      log "Set git core.excludesFile → $GITIGNORE"
    elif [[ "$CURRENT_EXCLUDES" != "$GITIGNORE" ]]; then
      GITIGNORE="$CURRENT_EXCLUDES"
      warn "Using existing core.excludesFile: $GITIGNORE"
    fi

    if ! grep -qxF "$GITIGNORE_ENTRY" "$GITIGNORE" 2>/dev/null; then
      echo "$GITIGNORE_ENTRY" >> "$GITIGNORE"
      log "Added '$GITIGNORE_ENTRY' to $GITIGNORE"
    else
      log ".ai.dump/ already in $GITIGNORE"
    fi
  fi
fi
echo

# ── Summary ──────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}Dry run complete. Re-run without --dry-run to apply.${NC}"
elif [[ -d "$BACKUP_DIR" ]]; then
  echo -e "${GREEN}Done.${NC} Backups saved to:"
  echo -e "  ${BLUE}$BACKUP_DIR/${NC}"
else
  echo -e "${GREEN}Done.${NC} No existing configs to backup."
fi

if [[ "$TARGET_HOME" != "$HOME" ]]; then
  echo
  echo -e "Verify layout:  ${BOLD}find $TARGET_HOME -type l | xargs ls -la${NC}"
fi
