.PHONY: all claude codex shared

all: claude codex

shared:
	./scripts/install-shared.sh

claude: shared
	./scripts/install-claude.sh

codex: shared
	./scripts/install-codex.sh
