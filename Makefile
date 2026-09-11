.PHONY: all claude codex copilot opencode cursor cursor-agent shared

.DEFAULT_GOAL := claude

all: claude codex copilot opencode cursor

shared:
	./scripts/install-shared.sh

claude: shared
	./scripts/install-claude.sh

codex: shared
	./scripts/install-codex.sh

copilot: shared
	./scripts/install-copilot.sh

opencode: shared
	./scripts/install-opencode.sh

cursor: shared
	./scripts/install-cursor.sh

cursor-agent: cursor
