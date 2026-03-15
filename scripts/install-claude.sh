#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for backup_and_link and variables
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

install_claude() {
  echo -e "${BOLD}Claude Code${NC}"

  mkdir -p "$TARGET_HOME/.claude"

  backup_and_link "$REPO_ROOT/claude/CLAUDE.md"      "$TARGET_HOME/.claude/CLAUDE.md"     "claude"
  backup_and_link "$REPO_ROOT/claude/hooks"           "$TARGET_HOME/.claude/hooks"         "claude"
  backup_and_link "$REPO_ROOT/claude/settings.json"   "$TARGET_HOME/.claude/settings.json" "claude"

  # Rules: individual symlinks so adding a workflow file is enough.
  # Remove old rules symlink from previous installs before mkdir.
  if [[ -L "$TARGET_HOME/.claude/rules" ]]; then
    if [[ "$DRY_RUN" != true ]]; then
      rm "$TARGET_HOME/.claude/rules"
    fi
  fi
  if [[ "$DRY_RUN" != true ]]; then
    mkdir -p "$TARGET_HOME/.claude/rules"
  fi
  backup_and_link "$REPO_ROOT/shared/general.md"  "$TARGET_HOME/.claude/rules/general.md"  "claude/rules"
  backup_and_link "$REPO_ROOT/shared/workflows"   "$TARGET_HOME/.claude/rules/workflows"   "claude/rules"
  # local/agents.md is not git-tracked; only link when present.
  if [[ -f "$REPO_ROOT/local/agents.md" ]]; then
    backup_and_link "$REPO_ROOT/local/agents.md"  "$TARGET_HOME/.claude/rules/local.md"  "claude/rules"
  fi

  # Verify all symlinks resolve
  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  local failed=0
  local links=(
    "$TARGET_HOME/.claude/CLAUDE.md"
    "$TARGET_HOME/.claude/hooks"
    "$TARGET_HOME/.claude/settings.json"
    "$TARGET_HOME/.claude/rules/general.md"
    "$TARGET_HOME/.claude/rules/workflows"
  )
  # Only verify local.md if it was linked
  if [[ -L "$TARGET_HOME/.claude/rules/local.md" ]]; then
    links+=("$TARGET_HOME/.claude/rules/local.md")
  fi

  for link in "${links[@]}"; do
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

echo -e "${BOLD}Agent Rules Installer (claude)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_claude
echo
echo -e "${GREEN}Done.${NC}"
