# Red Team slicing method

A whole codebase rarely fits one model's context, and a reviewer that sees a fragment misses the attacks
that cross module lines. This method gives every pass a complete, bounded view.

## 1. Measure the corpus
- Work from a read-only clone at an exact sha; record it in the plan's title.
- Exclude tests, binaries, fonts, lockfiles, generated files and docs. Keep code, SQL/migrations and deploy/proxy configs.
- Estimate tokens as `bytes / 4` (good enough for planning; swap in a real tokenizer if you have one).

## 2. Seed each surface
A **surface** is one way an attacker reaches the system: sign-in, the main query path, file access, admin,
background jobs, deploy/proxy config. For each, list **seed** globs: entry modules, their migrations, their configs.

## 3. Expand one hop
From each seed, follow imports **one hop** (verified from the syntax tree, not by grep). One hop is enough to
see what a surface calls without dragging in the whole app. Do not expand composition roots (the app factory,
the router registry) or offline CLIs into unrelated features; list those as out of slice.

## 4. Shared core, reviewed once
Every file used by **two or more** surfaces, plus foundational plumbing you name explicitly (DB access, row-level
security, roles, config, session handling), is the **shared core**. It is reviewed **once, in full**. If it is
over the slice cap, split it (core-A, core-B, ...) along package lines; it is still one review, in parts.

## 5. Surface slices
Each surface slice = its **own** files in full + **signature stubs** of the core it calls (function/class
headers with the first docstring line; for SQL/proxy/compose files, their contract headers). The reviewer
sees exactly how the surface uses the core without re-reading it.

## 6. Cap and pack
- Every slice stays under **~120K tokens** (leave room for instructions and the reviewer's output).
- Pack slices into passes (first-fit decreasing, ~160K per pass). Pair a core part with the surfaces that lean on it most.
- Run passes with **different models** in sequence. Every high or critical finding is fixed and retested before the next pass.

## 7. Record
The plan lists, per slice: files, own tokens, stub tokens, total; the passes; the sha; and anything out of
slice with the reason. Hand the plan file to the CTO; the CTO commits it to the review-log.

## Tool
`slicer.py` implements steps 1-6 for Python codebases (other file types join slices through seed globs only):

```bash
python3 redteam/slicer.py --repo ../myapp --config redteam/example-config.json \
    --json plan.json --emit /tmp/slices
```

Exit code 1 means a slice is over the cap: narrow its seeds or split the surface.
