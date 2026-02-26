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

  # Handle ~/.claude/rules as a real directory with per-file symlinks
  local rules_dir="$TARGET_HOME/.claude/rules"

  if [[ -L "$rules_dir" ]]; then
    # Old install used a directory symlink — back up and remove
    if [[ "$DRY_RUN" == true ]]; then
      info "[dry-run] Would remove old rules symlink $rules_dir"
    else
      mkdir -p "$BACKUP_DIR"
      cp -RL "$rules_dir" "$BACKUP_DIR/claude-rules" 2>/dev/null || true
      warn "Backed up old rules symlink $rules_dir"
      rm -f "$rules_dir"
    fi
  fi

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Would create $rules_dir/"
  else
    mkdir -p "$rules_dir"
  fi

  # Symlink shared/global-core.md
  backup_and_link "$REPO_ROOT/shared/global-core.md" "$rules_dir/global-core.md" "claude/rules"

  # Symlink each shared/workflows/*.md
  for f in "$REPO_ROOT"/shared/workflows/*.md; do
    local name
    name="$(basename "$f")"
    backup_and_link "$f" "$rules_dir/$name" "claude/rules"
  done

  # Verify all symlinks resolve
  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  local failed=0
  local link
  while IFS= read -r -d '' link; do
    if [[ -L "$link" ]] && [[ -e "$link" ]]; then
      log "OK: $link"
    else
      err "BROKEN: $link"
      failed=1
    fi
  done < <(find "$rules_dir" -name '*.md' -print0 2>/dev/null)

  for link in "$TARGET_HOME/.claude/CLAUDE.md" \
              "$TARGET_HOME/.claude/hooks" "$TARGET_HOME/.claude/settings.json"; do
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
