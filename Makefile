.PHONY: all claude shared

all: claude

shared:
	./scripts/install-shared.sh

claude: shared
	./scripts/install-claude.sh
