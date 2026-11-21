# noxibuilds-workshop - by @NoxiBuilds
.PHONY: check lint test leaks
SH := init.sh loop/queue-watch.sh loop/self-check.example.sh tests/smoke.sh tests/leak-scan.sh

check: lint test leaks

lint:
	@if command -v shellcheck >/dev/null; then shellcheck $(SH); else for f in $(SH); do bash -n $$f; done; fi
	@python3 -m py_compile redteam/slicer.py

test:
	@bash tests/smoke.sh

leaks:
	@bash tests/leak-scan.sh
