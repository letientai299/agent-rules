#!/bin/bash
set -euo pipefail

# Shared installer — sets up ~/.agent-rules symlink and global gitignore.
# Exports backup_and_link() for agent-specific installers to source.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$REPO_ROOT/.ai.dump/backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN="${DRY_RUN:-false}"
TARGET_HOME="${TARGET_HOME:-$HOME}"

# Parse flags only when run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--target) TARGET_HOME="$2"; shift 2 ;;
      -n|--dry-run) DRY_RUN=true; shift ;;
      -h|--help)
        echo "Usage: $(basename "$0") [--target DIR] [--dry-run] [--help]"
        exit 0
        ;;
      *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
  done
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

  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$target")"
    local parent_label="${label//\//-}"
    cp -RL "$target" "$BACKUP_DIR/${parent_label}-${backup_name}" 2>/dev/null || \
      cp -R "$target" "$BACKUP_DIR/${parent_label}-${backup_name}" 2>/dev/null || true
    warn "Backed up $target → $BACKUP_DIR/${parent_label}-${backup_name}"
    rm -rf "$target"
  fi

  mkdir -p "$(dirname "$target")"
  ln -sfn "$source" "$target"
  log "$label: $target → $source"
}

generate_routing_list() {
  local workflows_dir="$REPO_ROOT/shared/workflows"
  for f in "$workflows_dir"/*.md; do
    local title
    title="$(head -1 "$f" | sed 's/^# //')"
    local basename
    basename="$(basename "$f")"
    echo "- $title → \`~/.agent-rules/shared/workflows/$basename\`"
  done
}

# Copy a source file to target, replacing ROUTING markers with generated list.
copy_with_routing() {
  local source="$1"
  local target="$2"
  local label="$3"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -e "$target" || -L "$target" ]]; then
      info "[dry-run] Would backup $target → $BACKUP_DIR/"
    fi
    info "[dry-run] Would copy $source → $target (with routing list)"
    return
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    local backup_name
    backup_name="$(basename "$target")"
    local parent_label="${label//\//-}"
    cp -RL "$target" "$BACKUP_DIR/${parent_label}-${backup_name}" 2>/dev/null || \
      cp -R "$target" "$BACKUP_DIR/${parent_label}-${backup_name}" 2>/dev/null || true
    warn "Backed up $target → $BACKUP_DIR/${parent_label}-${backup_name}"
    rm -rf "$target"
  fi

  mkdir -p "$(dirname "$target")"
  cp "$source" "$target"

  # Replace everything between ROUTING markers with the generated list
  local routing_file
  routing_file="$(mktemp)"
  generate_routing_list > "$routing_file"

  local tmpfile
  tmpfile="$(mktemp)"
  awk -v rfile="$routing_file" '
    /<!-- ROUTING:START -->/ { print; while ((getline line < rfile) > 0) print line; skip=1; next }
    /<!-- ROUTING:END -->/   { skip=0 }
    !skip                    { print }
  ' "$target" > "$tmpfile"
  mv "$tmpfile" "$target"
  rm -f "$routing_file"

  log "$label: $target (copied + routing list generated)"
}

install_shared() {
  echo -e "${BOLD}Shared Rules${NC}"
  backup_and_link "$REPO_ROOT" "$TARGET_HOME/.agent-rules" "shared"

  # Global gitignore
  echo
  echo -e "${BOLD}Global gitignore${NC}"

  local gitignore="$TARGET_HOME/.gitignore"
  local entry=".ai.dump/"

  if [[ "$TARGET_HOME" != "$HOME" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      info "[dry-run] Would create $gitignore with '$entry'"
    else
      if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
        echo "$entry" >> "$gitignore"
        log "Added '$entry' to $gitignore"
      else
        log ".ai.dump/ already in $gitignore"
      fi
    fi
  else
    local current_excludes
    current_excludes=$(git config --global core.excludesFile 2>/dev/null || echo "")
    current_excludes="${current_excludes/#\~/$HOME}"

    if [[ "$DRY_RUN" == true ]]; then
      if [[ -z "$current_excludes" ]]; then
        info "[dry-run] Would set git core.excludesFile → $gitignore"
      fi
      if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
        info "[dry-run] Would add '$entry' to $gitignore"
      else
        log ".ai.dump/ already in $gitignore"
      fi
    else
      if [[ -z "$current_excludes" ]]; then
        git config --global core.excludesFile "$gitignore"
        log "Set git core.excludesFile → $gitignore"
      elif [[ "$current_excludes" != "$gitignore" ]]; then
        gitignore="$current_excludes"
        warn "Using existing core.excludesFile: $gitignore"
      fi

      if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
        echo "$entry" >> "$gitignore"
        log "Added '$entry' to $gitignore"
      else
        log ".ai.dump/ already in $gitignore"
      fi
    fi
  fi
}

# Run when executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo -e "${BOLD}Agent Rules Installer (shared)${NC}"
  echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
  echo
  install_shared
  echo
  echo -e "${GREEN}Done.${NC}"
fi
