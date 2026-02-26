#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for shared variables and logging helpers.
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

backup_and_copy() {
  local source="$1"
  local target="$2"
  local label="$3"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -e "$target" || -L "$target" ]]; then
      info "[dry-run] Would backup $target → $BACKUP_DIR/"
    fi
    info "[dry-run] Would copy $source → $target"
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
  log "$label: $target ← $source"
}

install_gemini() {
  echo -e "${BOLD}Gemini${NC}"

  mkdir -p "$TARGET_HOME/.gemini"

  # Gemini CLI does not follow symlinked global files, so copy instead.
  backup_and_copy "$REPO_ROOT/gemini/GEMINI.md" "$TARGET_HOME/.gemini/GEMINI.md" "gemini"
  backup_and_copy "$REPO_ROOT/gemini/settings.json" "$TARGET_HOME/.gemini/settings.json" "gemini"

  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  if [[ -f "$TARGET_HOME/.gemini/GEMINI.md" ]] && [[ -f "$TARGET_HOME/.gemini/settings.json" ]]; then
    log "OK: $TARGET_HOME/.gemini/GEMINI.md"
    log "OK: $TARGET_HOME/.gemini/settings.json"
    echo -e "${GREEN}All Gemini files verified.${NC}"
  else
    err "BROKEN: Gemini global files were not installed correctly"
    return 1
  fi
}

echo -e "${BOLD}Agent Rules Installer (gemini)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_gemini
echo
echo -e "${GREEN}Done.${NC}"
