# Synthesis and Physical Design

The immediate delivery is one reproducible Synopsys synthesis baseline for the chip and every unit, with explicit stubs where RTL is missing.

## Start here

1. Read [the current assignment and artifact locations](docs/START-HERE.md).
2. Complete [AI setup and the capture check](docs/git-ai.md) before AI edits or
   your first commit. Every clone needs its local hook activated.
3. Work on a branch and open a PR for `@abhinavnandwani` using
   [CONTRIBUTING.md](CONTRIBUTING.md). Main requires a code-owner approval;
   admins can bypass.

## Current issues

- [Chip-level synthesis with unit stubs](https://github.com/SiliconBadgers/physical-design/issues/2)
- [Every-unit synthesis targets and reports](https://github.com/SiliconBadgers/physical-design/issues/3)

## Repository structure

| Location | Purpose |
|---|---|
| [flows/synopsys/](flows/synopsys/README.md) | Team-owned chip/unit synthesis scripts, unit manifest and source selection for issues #2 and #3. Record tool versions and a single baseline library/corner; no licensed files in Git. |
| [rtl/stubs/](rtl/stubs/README.md) | Clearly labeled temporary synthesizable stubs, separated from real component RTL. Their ports are proposals; coordinate them with RTL owners. |
| [rtl/wrappers/](rtl/wrappers/README.md) | Chip assembly and unit wrappers that consume revision-pinned component sources. Do not copy authoritative component implementations here. |
| [constraints/](constraints/README.md) | Chip and per-unit baseline clocks, I/O assumptions and justified exceptions. Identify unresolved constraints instead of quietly treating them as met. |
| [reports/](reports/README.md) | Compact curated run summaries and links to evidence, including real/stub/black-box status and unavailable measurements. Generated tool databases/netlists live outside Git unless explicitly reviewed. |

## Current material and scope

No Synopsys synthesis run is supplied or claimed by this refresh. The chip flow, all-unit runner and reports remain the two team assignments.

[Shared diagram](https://github.com/SiliconBadgers/architecture/blob/main/docs/accelerator-diagram.md) · [Software evidence](https://github.com/SiliconBadgers/software/tree/main/experiments/llama-cpp/2026-09-22)

[CHARTER.md](CHARTER.md) and [OBJECTIVES.md](OBJECTIVES.md) describe the
longer-term purpose. Current issues and the starting guide specify the work
assigned now. [SETUP.md](SETUP.md) describes existing example commands and scope.
