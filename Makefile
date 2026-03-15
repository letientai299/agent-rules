.PHONY: all claude codex copilot opencode shared

.DEFAULT_GOAL := claude

all: claude codex copilot opencode

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
