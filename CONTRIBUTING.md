# Contributing

Thanks for helping. This kit is small on purpose; contributions that keep it small and generic are the most welcome.

## Ground rules
- **Generic only.** No project names, people, domains, emails, hostnames, machine ids or private URLs in code, docs or examples. Use placeholders like `<project>` or `example.com`.
- **No secrets, ever.** Keys come from env or chmod-600 files read at runtime; never from argv, never committed.
- **Small diffs.** One change per PR, with the why in the description. The kit preaches micro-slices; it should practice them.
- **Safe by default.** Nothing in the kit may install, enable or start a service, push, or contact the network unless the user runs that step explicitly.

## Before you open a PR
```bash
make check        # shellcheck (or bash -n), python compile, smoke tests, leak scan
```
or by hand:
```bash
shellcheck init.sh loop/*.sh tests/*.sh     # or: bash -n <file>
python3 -m py_compile redteam/slicer.py
bash tests/smoke.sh
bash tests/leak-scan.sh
```

## Style
- Bash: `set -euo pipefail`, quote everything, `shellcheck` clean, a header comment that says what and why.
- Python: stdlib only, type hints, `python3 -m py_compile` clean.
- Docs: short sentences, concrete examples, no marketing.

## Reporting a security issue
Please do not open a public issue. Contact the maintainers privately (see the repository's security policy) with steps to reproduce.
