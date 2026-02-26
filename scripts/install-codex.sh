#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for backup_and_link and variables
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

install_codex() {
  echo -e "${BOLD}Codex${NC}"

  mkdir -p "$TARGET_HOME/.codex"

  # Codex uses a single AGENTS.md — no rules directory support
  backup_and_link "$REPO_ROOT/codex/AGENTS.md" "$TARGET_HOME/.codex/AGENTS.md" "codex"

  # Verify
  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  if [[ -L "$TARGET_HOME/.codex/AGENTS.md" ]] && [[ -e "$TARGET_HOME/.codex/AGENTS.md" ]]; then
    log "OK: $TARGET_HOME/.codex/AGENTS.md"
    echo -e "${GREEN}All symlinks verified.${NC}"
  else
    err "BROKEN: $TARGET_HOME/.codex/AGENTS.md"
    return 1
  fi
}

echo -e "${BOLD}Agent Rules Installer (codex)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_codex
echo
echo -e "${GREEN}Done.${NC}"
