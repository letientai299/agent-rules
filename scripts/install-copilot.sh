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

  # Hooks: symlink hooks directory and hooks.json
  backup_and_link "$REPO_ROOT/copilot/hooks" \
    "$TARGET_HOME/.copilot/hooks" "copilot"
  backup_and_link "$REPO_ROOT/copilot/hooks.json" \
    "$TARGET_HOME/.copilot/hooks.json" "copilot"

  # Verify
  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  local failed=0
  for link in "$TARGET_HOME/.copilot/copilot-instructions.md" \
              "$TARGET_HOME/.copilot/hooks" \
              "$TARGET_HOME/.copilot/hooks.json"; do
    if [[ -L "$link" ]] && [[ -e "$link" ]]; then
      log "OK: $link"
    else
      err "BROKEN: $link"
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All symlinks verified.${NC}"
  else
    err "Some symlinks are broken."
    return 1
  fi
}

echo -e "${BOLD}Agent Rules Installer (copilot)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_copilot
echo
echo -e "${GREEN}Done.${NC}"
