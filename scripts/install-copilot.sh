#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for backup_and_link and variables
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

install_copilot() {
  echo -e "${BOLD}Copilot${NC}"

  mkdir -p "$TARGET_HOME/.copilot"

  # Copilot reads ~/.copilot/copilot-instructions.md for global instructions
  backup_and_link "$REPO_ROOT/copilot/copilot-instructions.md" \
    "$TARGET_HOME/.copilot/copilot-instructions.md" "copilot"

  # Verify
  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  if [[ -L "$TARGET_HOME/.copilot/copilot-instructions.md" ]] && \
     [[ -e "$TARGET_HOME/.copilot/copilot-instructions.md" ]]; then
    log "OK: $TARGET_HOME/.copilot/copilot-instructions.md"
    echo -e "${GREEN}All symlinks verified.${NC}"
  else
    err "BROKEN: $TARGET_HOME/.copilot/copilot-instructions.md"
    return 1
  fi
}

echo -e "${BOLD}Agent Rules Installer (copilot)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_copilot
echo
echo -e "${GREEN}Done.${NC}"
