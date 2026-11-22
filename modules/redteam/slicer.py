#!/usr/bin/env python3
"""slicer.py - plan Red Team review slices for a repository (Python stdlib only).

Method (see SLICING.md):
  1. Each named surface starts from seed globs (entry modules, migrations, configs).
  2. Python seeds expand ONE hop along their imports (resolved with `ast` to files inside the repo).
  3. Files used by two or more surfaces, plus any `core:` globs, form the SHARED CORE, reviewed once.
     If the core is over the cap it is split into core-A, core-B, ... by top-level package.
  4. Each surface slice = its own files in full + signature stubs (def/class headers) of the core files
     those own files import.
  5. Tokens are estimated as bytes / 4. Every slice must fit --cap (default 120000).
  6. Slices are packed into review passes (first-fit decreasing, --pass-cap, default 160000).

Config (JSON):
  {
    "exclude": ["**/tests/**", "**/test_*.py", "**/*_test.py"],
    "core":    ["src/app/db/**"],
    "surfaces": {
      "sign-in": ["src/app/auth/**", "migrations/*_auth*.sql"],
      "billing": ["src/app/billing/**"]
    }
  }

Usage:
  slicer.py --repo PATH --config slices.json [--cap 120000] [--pass-cap 160000] [--json out.json] [--emit DIR]

Prints a Markdown plan. --json writes the machine-readable plan; --emit writes one text bundle per slice
(own files in full, then core stubs) ready to hand to a reviewer model.
"""
from __future__ import annotations

import argparse
import ast
import fnmatch
import json
import sys
from pathlib import Path

DEFAULT_EXCLUDE = ["**/tests/**", "**/test_*.py", "**/*_test.py", "**/.git/**", "**/node_modules/**",
                   "**/*.lock", "**/*.png", "**/*.jpg", "**/*.woff*", "**/*.ico"]


def tokens(n_bytes: int) -> float:
    return n_bytes / 4


def match(rel: str, patterns: list[str]) -> bool:
    for p in patterns:
        if fnmatch.fnmatchcase(rel, p) or (p.startswith("**/") and fnmatch.fnmatchcase(rel, p[3:])):
            return True
    return False


def list_files(repo: Path, exclude: list[str]) -> list[str]:
    out = []
    for f in repo.rglob("*"):
        if f.is_file():
            rel = f.relative_to(repo).as_posix()
            if not match(rel, exclude):
                out.append(rel)
    return sorted(out)


def module_index(files: list[str]) -> dict[str, str]:
    """Map dotted module names to files, for every package root a file could be imported from."""
    idx: dict[str, str] = {}
    for rel in files:
        if not rel.endswith(".py"):
            continue
        parts = rel[:-3].split("/")
        if parts[-1] == "__init__":
            parts = parts[:-1]
        for start in range(len(parts)):  # src/pkg/mod.py is importable as pkg.mod and src.pkg.mod
            name = ".".join(parts[start:])
            if name:
                idx.setdefault(name, rel)
    return idx


def imports_of(repo: Path, rel: str, idx: dict[str, str]) -> set[str]:
    try:
        tree = ast.parse((repo / rel).read_text(encoding="utf-8", errors="replace"), filename=rel)
    except SyntaxError:
        return set()
    pkg = rel[:-3].split("/")[:-1] if not rel.endswith("__init__.py") else rel.split("/")[:-1]
    found: set[str] = set()

    def add(name: str) -> bool:
        while name:
            if name in idx:
                found.add(idx[name])
                return True
            name = name.rpartition(".")[0]
        return False

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for a in node.names:
                add(a.name)
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                base = pkg[: len(pkg) - (node.level - 1)] if node.level > 1 else pkg
                mod = ".".join(base + ([node.module] if node.module else []))
            else:
                mod = node.module or ""
            # `from pkg import mod` imports pkg/mod.py; fall back to the package itself only for names in it.
            for a in node.names:
                full = f"{mod}.{a.name}" if mod else a.name
                if full in idx:
                    found.add(idx[full])
                else:
                    add(mod)
    found.discard(rel)
    return found


def stub(repo: Path, rel: str) -> str:
    """def/class headers (with first docstring line) of a Python file; first 40 lines of anything else."""
    text = (repo / rel).read_text(encoding="utf-8", errors="replace")
    if not rel.endswith(".py"):
        return "\n".join(text.splitlines()[:40])
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return ""
    lines = text.splitlines()
    out = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            head = lines[node.lineno - 1].strip()
            doc = ast.get_docstring(node)
            out.append((node.lineno, head + (f"  # {doc.splitlines()[0]}" if doc else "")))
    return "\n".join(h for _, h in sorted(out))


def split_core(core: list[str], size: dict[str, int], cap: int) -> list[list[str]]:
    groups: dict[str, list[str]] = {}
    for rel in core:
        key = "/".join(rel.split("/")[:2])
        groups.setdefault(key, []).append(rel)
    chunks: list[list[str]] = []
    cur: list[str] = []
    cur_tok = 0.0
    for key in sorted(groups, key=lambda k: -sum(size[f] for f in groups[k])):
        for rel in sorted(groups[key]):
            t = tokens(size[rel])
            if cur and cur_tok + t > cap:
                chunks.append(cur)
                cur, cur_tok = [], 0.0
            cur.append(rel)
            cur_tok += t
    if cur:
        chunks.append(cur)
    return chunks


def pack(slices: list[dict], pass_cap: int) -> list[list[str]]:
    bins: list[tuple[float, list[str]]] = []
    for s in sorted(slices, key=lambda s: -s["tokens"]):
        for i, (t, names) in enumerate(bins):
            if t + s["tokens"] <= pass_cap:
                bins[i] = (t + s["tokens"], names + [s["name"]])
                break
        else:
            bins.append((s["tokens"], [s["name"]]))
    return [names for _, names in bins]


def plan(repo: Path, cfg: dict, cap: int, pass_cap: int) -> dict:
    exclude = DEFAULT_EXCLUDE + cfg.get("exclude", [])
    files = list_files(repo, exclude)
    size = {f: (repo / f).stat().st_size for f in files}
    idx = module_index(files)
    members: dict[str, set[str]] = {}
    for name, seeds in cfg["surfaces"].items():
        seed_files = {f for f in files if match(f, seeds)}
        hop = set()
        for f in seed_files:
            if f.endswith(".py"):
                hop |= imports_of(repo, f, idx)
        members[name] = seed_files | hop
    counts: dict[str, int] = {}
    for s in members.values():
        for f in s:
            counts[f] = counts.get(f, 0) + 1
    core = sorted({f for f, c in counts.items() if c >= 2} | {f for f in files if match(f, cfg.get("core", []))})
    core_set = set(core)
    slices = []
    for i, chunk in enumerate(split_core(core, size, cap) if core else []):
        slices.append({"name": f"core-{chr(65 + i)}", "kind": "core", "files": chunk, "stubs": [],
                       "tokens": round(sum(tokens(size[f]) for f in chunk), 1)})
    for name, s in members.items():
        own = sorted(s - core_set)
        used_core = sorted({c for f in own if f.endswith(".py") for c in imports_of(repo, f, idx)} & core_set)
        stub_tok = sum(tokens(len(stub(repo, c).encode())) for c in used_core)
        slices.append({"name": name, "kind": "surface", "files": own, "stubs": used_core,
                       "tokens": round(sum(tokens(size[f]) for f in own) + stub_tok, 1)})
    over = [s["name"] for s in slices if s["tokens"] > cap]
    return {"repo": str(repo), "cap": cap, "pass_cap": pass_cap, "slices": slices,
            "passes": pack(slices, pass_cap), "over_cap": over}


def markdown(p: dict) -> str:
    out = [f"# Red Team slice plan (cap {p['cap']:,} tok/slice, {p['pass_cap']:,} tok/pass)", "",
           "| Slice | Kind | Own files | Core stubs | Tokens (B/4) |", "| --- | --- | ---: | ---: | ---: |"]
    for s in p["slices"]:
        out.append(f"| {s['name']} | {s['kind']} | {len(s['files'])} | {len(s['stubs'])} | {s['tokens']:,} |")
    out += ["", "## Passes"]
    by = {s["name"]: s["tokens"] for s in p["slices"]}
    for i, names in enumerate(p["passes"], 1):
        out.append(f"{i}. {' + '.join(names)} = {sum(by[n] for n in names):,.1f} tok")
    if p["over_cap"]:
        out += ["", f"**Over cap:** {', '.join(p['over_cap'])} - narrow the seeds or split the surface."]
    return "\n".join(out) + "\n"


def emit(repo: Path, p: dict, outdir: Path) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    for s in p["slices"]:
        parts = [f"# slice {s['name']} ({s['kind']}), ~{s['tokens']:,} tok\n"]
        for f in s["files"]:
            parts.append(f"\n===== FILE {f} =====\n{(repo / f).read_text(encoding='utf-8', errors='replace')}")
        for c in s["stubs"]:
            parts.append(f"\n===== CORE STUB {c} (reviewed in the core slice) =====\n{stub(repo, c)}\n")
        (outdir / f"{s['name']}.txt").write_text("".join(parts), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Plan Red Team review slices.")
    ap.add_argument("--repo", required=True, type=Path)
    ap.add_argument("--config", required=True, type=Path)
    ap.add_argument("--cap", type=int, default=120_000)
    ap.add_argument("--pass-cap", type=int, default=160_000)
    ap.add_argument("--json", type=Path)
    ap.add_argument("--emit", type=Path)
    a = ap.parse_args(argv)
    cfg = json.loads(a.config.read_text(encoding="utf-8"))
    if not cfg.get("surfaces"):
        print("slicer: config needs a non-empty 'surfaces' map", file=sys.stderr)
        return 2
    p = plan(a.repo.resolve(), cfg, a.cap, a.pass_cap)
    sys.stdout.write(markdown(p))
    if a.json:
        a.json.write_text(json.dumps(p, indent=2) + "\n", encoding="utf-8")
    if a.emit:
        emit(a.repo.resolve(), p, a.emit)
    return 1 if p["over_cap"] else 0


if __name__ == "__main__":
    sys.exit(main())
