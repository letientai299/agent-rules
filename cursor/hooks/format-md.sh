#!/bin/bash
# afterFileEdit hook: format markdown files after Agent edits.
# Cursor passes JSON on stdin with file_path.
#
# Picks the markdown formatter the repo actually uses instead of hardcoding
# prettier. Walks up from the edited file to the repo root; the closest
# directory holding a formatter config wins (respects monorepo sub-packages).
# Priority within a directory: rumdl > mdformat > dprint > prettier. Each tool
# auto-discovers its own config from the file's location, so no config path is
# passed explicitly. Falls back to prettier when no config is found.
#
# If the detected tool's config exists but the tool isn't installed, the hook
# exits 2 with a reminder.

set -euo pipefail

input=$(cat)

file_path=$(echo "$input" | jq -r '.file_path // empty')

# Only format markdown files that exist.
[[ "$file_path" == *.md ]] && [[ -f "$file_path" ]] || exit 0

# Detect the formatter by walking up from the file's directory. Echoes the
# tool name on the first directory that carries a recognized config, else "".
detect_formatter() {
	local dir
	dir=$(cd "$(dirname "$file_path")" && pwd)

	local precommit
	while :; do
		precommit="$dir/.pre-commit-config.yaml"
		# rumdl: dedicated markdown linter/formatter. It also discovers
		# .config/rumdl.toml. .rumdl_cache/ is left behind after a run, so it
		# marks usage even without a config file.
		if [[ -f "$dir/.rumdl.toml" || -f "$dir/rumdl.toml" || -f "$dir/.config/rumdl.toml" || -d "$dir/.rumdl_cache" ]] ||
			{ [[ -f "$dir/pyproject.toml" ]] && grep -q '^\[tool\.rumdl' "$dir/pyproject.toml"; } ||
			{ [[ -f "$precommit" ]] && grep -q 'rumdl' "$precommit"; }; then
			echo rumdl
			return
		fi
		# mdformat: python markdown formatter.
		if [[ -f "$dir/.mdformat.toml" ]] ||
			{ [[ -f "$dir/pyproject.toml" ]] && grep -q '^\[tool\.mdformat' "$dir/pyproject.toml"; } ||
			{ [[ -f "$precommit" ]] && grep -q 'mdformat' "$precommit"; }; then
			echo mdformat
			return
		fi
		# dprint: multi-language formatter. Only these four root names are
		# auto-discovered — .config/ applies only to the global user config.
		if [[ -f "$dir/dprint.json" || -f "$dir/dprint.jsonc" || -f "$dir/.dprint.json" || -f "$dir/.dprint.jsonc" ]]; then
			echo dprint
			return
		fi
		# prettier: config files, a "prettier" key in package.json, or a hook.
		if compgen -G "$dir/.prettierrc*" >/dev/null 2>&1 ||
			compgen -G "$dir/prettier.config.*" >/dev/null 2>&1 ||
			{ [[ -f "$dir/package.json" ]] && grep -q '"prettier"' "$dir/package.json"; } ||
			{ [[ -f "$precommit" ]] && grep -q 'prettier' "$precommit"; }; then
			echo prettier
			return
		fi

		# Stop after the repo root; break when we can't go higher.
		[[ -e "$dir/.git" ]] && break
		[[ "$dir" == "/" ]] && break
		dir=$(dirname "$dir")
	done

	echo ""
}

run_formatter() {
	case "$1" in
	rumdl) rumdl fmt "$file_path" >/dev/null 2>&1 || true ;;
	mdformat) mdformat "$file_path" >/dev/null 2>&1 || true ;;
	dprint) dprint fmt "$file_path" >/dev/null 2>&1 || true ;;
	# --ignore-path='' because prettier v3+ skips gitignored files by default.
	prettier) prettier --write --ignore-path='' "$file_path" >/dev/null 2>&1 || true ;;
	esac
}

tool=$(detect_formatter)

# No repo config found: format with prettier if available, else do nothing.
if [[ -z "$tool" ]]; then
	command -v prettier &>/dev/null && run_formatter prettier
	exit 0
fi

# Detected a tool but it isn't installed — remind the agent instead of silently
# falling back to the wrong formatter.
if ! command -v "$tool" &>/dev/null; then
	echo "This repo is configured to format markdown with '$tool', which is not installed. Install it (or format $file_path manually) — do not use a different formatter." >&2
	exit 2
fi

run_formatter "$tool"
exit 0
