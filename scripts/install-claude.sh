#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for force_link and variables
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

install_claude() {
  echo -e "${BOLD}Claude Code${NC}"

  mkdir -p "$TARGET_HOME/.claude"

  force_link "$REPO_ROOT/claude/CLAUDE.md"      "$TARGET_HOME/.claude/CLAUDE.md"     "claude"
  force_link "$REPO_ROOT/claude/hooks"           "$TARGET_HOME/.claude/hooks"         "claude"

  # Merge hooks config into existing settings.json (don't overwrite volatile fields).
  local settings="$TARGET_HOME/.claude/settings.json"
  local hooks_src="$REPO_ROOT/claude/hooks.json"
  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Would merge $hooks_src into $settings"
  else
    if [[ ! -f "$settings" ]]; then
      cp "$hooks_src" "$settings"
      log "claude: created $settings from hooks.json"
    else
      # Materialize a symlink from a previous install before merging.
      if [[ -L "$settings" ]]; then
        local tmpfile
        tmpfile="$(mktemp)"
        cp -L "$settings" "$tmpfile"
        rm "$settings"
        mv "$tmpfile" "$settings"
      fi
      local tmpfile
      tmpfile="$(mktemp)"
      # Shallow merge: hooks.json's top-level keys (hooks, statusLine) replace
      # settings.json's wholesale, so hooks removed from hooks.json are pruned.
      # A deep merge (`*`) would leave stale sub-hooks behind. Other settings.json
      # keys not present in hooks.json are preserved.
      jq -s '.[0] + .[1]' "$settings" "$hooks_src" > "$tmpfile"
      mv "$tmpfile" "$settings"
      log "claude: merged hooks into $settings"
    fi
  fi

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
  force_link "$REPO_ROOT/shared/general.md"  "$TARGET_HOME/.claude/rules/general.md"  "claude/rules"
  force_link "$REPO_ROOT/shared/workflows"   "$TARGET_HOME/.claude/rules/workflows"   "claude/rules"
  # local/agents.md is not git-tracked; only link when present.
  if [[ -f "$REPO_ROOT/local/agents.md" ]]; then
    force_link "$REPO_ROOT/local/agents.md"  "$TARGET_HOME/.claude/rules/local.md"  "claude/rules"
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

  # settings.json is a regular file (merged, not symlinked)
  if [[ -f "$TARGET_HOME/.claude/settings.json" ]]; then
    log "OK: $TARGET_HOME/.claude/settings.json (merged)"
  else
    err "MISSING: $TARGET_HOME/.claude/settings.json"
    failed=1
  fi

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
