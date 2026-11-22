# Workshop kit checks.
.PHONY: check lint test structure leaks
SH := init.sh modules/claude-code-loop/loop/queue-watch.sh modules/claude-code-loop/loop/self-check.example.sh tests/smoke.sh tests/leak-scan.sh tests/structure.sh

check: lint test structure leaks

lint:
	@if command -v shellcheck >/dev/null; then shellcheck $(SH); else for f in $(SH); do bash -n $$f; done; fi
	@python3 -m py_compile modules/redteam/slicer.py

test:
	@bash tests/smoke.sh

structure:
	@bash tests/structure.sh

leaks:
	@bash tests/leak-scan.sh
