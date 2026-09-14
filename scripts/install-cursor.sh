#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for force_link and variables
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

# Cursor ignores plain .md in ~/.cursor/rules. Write .mdc pointers so the
# IDE Agent and cursor-agent CLI both load them as user rules.
write_mdc() {
  local dest="$1"
  local always_apply="$2"
  local description="$3"
  local globs="$4"
  local body="$5"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Would write $dest"
    return
  fi

  {
    echo "---"
    echo "alwaysApply: $always_apply"
    if [[ -n "$description" ]]; then
      printf 'description: %s\n' "$description"
    fi
    if [[ -n "$globs" ]]; then
      printf 'globs: %s\n' "$(yaml_quote "$globs")"
    fi
    echo "---"
    echo
    printf '%s\n' "$body"
  } >"$dest"
  log "cursor/rules: $dest"
}

yaml_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

lang_globs() {
  case "$1" in
  go.md) echo '**/*.go,go.mod,go.sum' ;;
  typescript.md) echo '**/*.ts,**/*.tsx,**/*.js,**/*.jsx,tsconfig.json,package.json' ;;
  react.md) echo '**/*.tsx,**/*.jsx' ;;
  csharp.md) echo '**/*.cs,**/*.csproj,**/*.sln' ;;
  sql.md) echo '**/*.sql,**/*.pgsql' ;;
  *) echo '' ;;
  esac
}

merge_hooks_json() {
  merge_hooks_file "$TARGET_HOME/.cursor/hooks.json" \
    "$REPO_ROOT/cursor/hooks.json" "cursor"
}

install_cursor() {
  echo -e "${BOLD}Cursor / cursor-agent${NC}"

  local rules_dir="$TARGET_HOME/.cursor/rules"
  mkdir -p "$rules_dir"
  link_shared_hooks "$TARGET_HOME/.cursor/hooks" "cursor"

  merge_hooks_json

  if [[ "$DRY_RUN" != true ]]; then
    rm -f "$rules_dir"/agent-rules-*.mdc
  fi

  write_mdc \
    "$rules_dir/agent-rules-general.mdc" \
    true \
    "" \
    "" \
    "MUST follow the Output Style section in \`~/.agent-rules/shared/general.md\` — facts only, no narration, no work summaries.

MUST read \`~/.agent-rules/shared/general.md\` at session start.

If \`~/.agent-rules/local/agents.md\` exists, MUST also read it.

Discover and read project rule files (\`AGENTS.md\` and \`agents.local.md\`) per the Local Overrides section in \`shared/general.md\`."

  local lang
  for lang in "$REPO_ROOT/shared/langs/"*.md; do
    [[ -f "$lang" ]] || continue
    local base title globs
    base="$(basename "$lang")"
    title="$(head -1 "$lang" | sed 's/^# //')"
    globs="$(lang_globs "$base")"
    if [[ -n "$globs" ]]; then
      write_mdc \
        "$rules_dir/agent-rules-lang-${base%.md}.mdc" \
        false \
        "$(yaml_quote "$title")" \
        "$globs" \
        "MUST read \`~/.agent-rules/shared/langs/$base\`."
    else
      write_mdc \
        "$rules_dir/agent-rules-lang-${base%.md}.mdc" \
        false \
        "$(yaml_quote "$title")" \
        "" \
        "MUST read \`~/.agent-rules/shared/langs/$base\` when this language is in use."
    fi
  done

  local workflow
  for workflow in "$REPO_ROOT/shared/workflows/"*.md; do
    [[ -f "$workflow" ]] || continue
    local base title
    base="$(basename "$workflow")"
    title="$(head -1 "$workflow" | sed 's/^# //')"
    write_mdc \
      "$rules_dir/agent-rules-workflow-${base%.md}.mdc" \
      false \
      "$(yaml_quote "$title")" \
      "" \
      "MUST read \`~/.agent-rules/shared/workflows/$base\` when this session matches."
  done

  if [[ -f "$REPO_ROOT/local/agents.md" ]]; then
    write_mdc \
      "$rules_dir/agent-rules-local.mdc" \
      true \
      "" \
      "" \
      "MUST read \`~/.agent-rules/local/agents.md\` — machine-local overrides."
  fi

  echo
  echo -e "${BOLD}Verification${NC}"

  if [[ "$DRY_RUN" == true ]]; then
    info "[dry-run] Skipping verification"
    return
  fi

  local failed=0
  local links=(
    "$TARGET_HOME/.cursor/hooks/safe-git.sh"
    "$TARGET_HOME/.cursor/hooks/format-md.sh"
  )

  for link in "${links[@]}"; do
    if [[ -L "$link" ]] && [[ -e "$link" ]]; then
      log "OK: $link"
    else
      err "BROKEN: $link"
      failed=1
    fi
  done

  if [[ -f "$TARGET_HOME/.cursor/hooks.json" ]]; then
    log "OK: $TARGET_HOME/.cursor/hooks.json (merged)"
  else
    err "MISSING: $TARGET_HOME/.cursor/hooks.json"
    failed=1
  fi

  if [[ -f "$rules_dir/agent-rules-general.mdc" ]]; then
    log "OK: $rules_dir/agent-rules-general.mdc"
  else
    err "MISSING: $rules_dir/agent-rules-general.mdc"
    failed=1
  fi

  if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All Cursor install paths verified.${NC}"
  else
    err "Some Cursor install paths are missing."
    return 1
  fi
}

echo -e "${BOLD}Agent Rules Installer (cursor)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_cursor
echo
echo -e "${GREEN}Done.${NC}"
