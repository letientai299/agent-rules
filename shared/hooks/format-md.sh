#!/bin/bash
# Format markdown after an edit. Payload shapes:
# Claude/Codex PostToolUse: .tool_input.file_path or apply_patch in
# .tool_input.command
# Cursor afterFileEdit: .file_path
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
cwd=$(echo "$input" | jq -r '.cwd // empty')
missing_tool=""

resolve_path() {
	local p="$1"
	[[ -z "$p" || "$p" == "null" ]] && return
	if [[ "$p" == /* ]]; then
		echo "$p"
	elif [[ -n "$cwd" ]]; then
		echo "$cwd/$p"
	else
		echo "$p"
	fi
}

detect_formatter() {
	local file_path="$1"
	local dir
	dir=$(cd "$(dirname "$file_path")" && pwd)

	local precommit
	while :; do
		precommit="$dir/.pre-commit-config.yaml"
		if [[ -f "$dir/.rumdl.toml" || -f "$dir/rumdl.toml" || -f "$dir/.config/rumdl.toml" || -d "$dir/.rumdl_cache" ]] ||
			{ [[ -f "$dir/pyproject.toml" ]] && grep -q '^\[tool\.rumdl' "$dir/pyproject.toml"; } ||
			{ [[ -f "$precommit" ]] && grep -q 'rumdl' "$precommit"; }; then
			echo rumdl
			return
		fi
		if [[ -f "$dir/.mdformat.toml" ]] ||
			{ [[ -f "$dir/pyproject.toml" ]] && grep -q '^\[tool\.mdformat' "$dir/pyproject.toml"; } ||
			{ [[ -f "$precommit" ]] && grep -q 'mdformat' "$precommit"; }; then
			echo mdformat
			return
		fi
		if [[ -f "$dir/dprint.json" || -f "$dir/dprint.jsonc" || -f "$dir/.dprint.json" || -f "$dir/.dprint.jsonc" ]]; then
			echo dprint
			return
		fi
		if compgen -G "$dir/.prettierrc*" >/dev/null 2>&1 ||
			compgen -G "$dir/prettier.config.*" >/dev/null 2>&1 ||
			{ [[ -f "$dir/package.json" ]] && grep -q '"prettier"' "$dir/package.json"; } ||
			{ [[ -f "$precommit" ]] && grep -q 'prettier' "$precommit"; }; then
			echo prettier
			return
		fi

		[[ -e "$dir/.git" ]] && break
		[[ "$dir" == "/" ]] && break
		dir=$(dirname "$dir")
	done

	echo ""
}

run_formatter() {
	local tool="$1"
	local file_path="$2"
	case "$tool" in
	rumdl) rumdl fmt "$file_path" >/dev/null 2>&1 || true ;;
	mdformat) mdformat "$file_path" >/dev/null 2>&1 || true ;;
	dprint) dprint fmt "$file_path" >/dev/null 2>&1 || true ;;
	prettier) prettier --write --ignore-path='' "$file_path" >/dev/null 2>&1 || true ;;
	esac
}

format_md() {
	local file_path="$1"
	[[ "$file_path" == *.md ]] && [[ -f "$file_path" ]] || return 0

	local tool
	tool=$(detect_formatter "$file_path")

	if [[ -z "$tool" ]]; then
		command -v prettier &>/dev/null && run_formatter prettier "$file_path"
		return 0
	fi

	if ! command -v "$tool" &>/dev/null; then
		missing_tool="$tool:$file_path"
		return 0
	fi

	run_formatter "$tool" "$file_path"
}

paths=$(echo "$input" | jq -r '
	[.file_path // empty, .tool_input.file_path // empty, .tool_input.path // empty]
	| .[] | select(. != "")
')
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
patch_paths=$(printf '%s\n' "$cmd" | awk '
	/^\*\*\* Add File: / { sub(/^\*\*\* Add File: /, ""); print }
	/^\*\*\* Update File: / { sub(/^\*\*\* Update File: /, ""); print }
')

seen=""
while IFS= read -r raw; do
	[[ -z "$raw" ]] && continue
	resolved=$(resolve_path "$raw")
	case " $seen " in
	*" $resolved "*) continue ;;
	esac
	seen="$seen $resolved"
	format_md "$resolved"
done <<EOF
$paths
$patch_paths
EOF

if [[ -n "$missing_tool" ]]; then
	tool=${missing_tool%%:*}
	file_path=${missing_tool#*:}
	echo "This repo is configured to format markdown with '$tool', which is not installed. Install it (or format $file_path manually) — do not use a different formatter." >&2
	exit 2
fi

exit 0
