#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for force_link and variables
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

install_codex() {
  echo -e "${BOLD}Codex${NC}"

  mkdir -p "$TARGET_HOME/.codex"

  # Codex uses a single AGENTS.md — no rules directory support
  # Copy instead of symlink so we can inject the generated routing list
  copy_with_routing "$REPO_ROOT/codex/AGENTS.md" "$TARGET_HOME/.codex/AGENTS.md" "codex"
  link_shared_hooks "$TARGET_HOME/.codex/hooks" "codex"
  force_link "$REPO_ROOT/codex/hooks.json" "$TARGET_HOME/.codex/hooks.json" "codex"

  # Verify
  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  local failed=0
  if [[ -e "$TARGET_HOME/.codex/AGENTS.md" ]]; then
    log "OK: $TARGET_HOME/.codex/AGENTS.md"
  else
    err "BROKEN: $TARGET_HOME/.codex/AGENTS.md"
    failed=1
  fi

  local link
  for link in "$TARGET_HOME/.codex/hooks.json" \
              "$TARGET_HOME/.codex/hooks/safe-git.sh" \
              "$TARGET_HOME/.codex/hooks/format-md.sh"; do
    if [[ -L "$link" ]] && [[ -e "$link" ]]; then
      log "OK: $link"
    else
      err "BROKEN: $link"
      failed=1
    fi
  done

  if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All Codex install paths verified.${NC}"
    warn "Codex skips new hooks until you trust them in /hooks"
  else
    err "Some Codex install paths are missing."
    return 1
  fi
}

echo -e "${BOLD}Agent Rules Installer (codex)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_codex
echo
echo -e "${GREEN}Done.${NC}"
