#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared installer for backup_and_link and variables
# shellcheck source=install-shared.sh
source "$SCRIPT_DIR/install-shared.sh"

install_opencode() {
	echo -e "${BOLD}OpenCode${NC}"

	local config_dir="$TARGET_HOME/.config/opencode"
	mkdir -p "$config_dir"

	backup_and_link "$REPO_ROOT/opencode/AGENTS.md" "$config_dir/AGENTS.md" "opencode"
	backup_and_link "$REPO_ROOT/opencode/opencode.json" "$config_dir/opencode.json" "opencode"
	backup_and_link "$REPO_ROOT/opencode/plugins" "$config_dir/plugins" "opencode"

	# Rules: individual symlinks so adding a workflow file is enough.
	# Remove old rules symlink from previous installs before mkdir.
	if [[ -L "$config_dir/rules" ]]; then
		if [[ "$DRY_RUN" != true ]]; then
			rm "$config_dir/rules"
		fi
	fi
	if [[ "$DRY_RUN" != true ]]; then
		mkdir -p "$config_dir/rules"
	fi
	backup_and_link "$REPO_ROOT/shared/general.md" "$config_dir/rules/general.md" "opencode/rules"
	backup_and_link "$REPO_ROOT/shared/workflows" "$config_dir/rules/workflows" "opencode/rules"
	# local/agents.md is not git-tracked; only link when present.
	if [[ -f "$REPO_ROOT/local/agents.md" ]]; then
		backup_and_link "$REPO_ROOT/local/agents.md" "$config_dir/rules/local.md" "opencode/rules"
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
		"$config_dir/AGENTS.md"
		"$config_dir/opencode.json"
		"$config_dir/plugins"
		"$config_dir/rules/general.md"
		"$config_dir/rules/workflows"
	)
	# Only verify local.md if it was linked
	if [[ -L "$config_dir/rules/local.md" ]]; then
		links+=("$config_dir/rules/local.md")
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

echo -e "${BOLD}Agent Rules Installer (opencode)${NC}"
echo -e "Source: ${BLUE}$REPO_ROOT${NC}"
echo
install_opencode
echo
echo -e "${GREEN}Done.${NC}"
