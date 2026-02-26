.PHONY: all claude codex copilot gemini shared

all: claude codex copilot gemini

shared:
	./scripts/install-shared.sh

claude: shared
	./scripts/install-claude.sh

codex: shared
	./scripts/install-codex.sh

copilot: shared
	./scripts/install-copilot.sh

gemini: shared
	./scripts/install-gemini.sh
