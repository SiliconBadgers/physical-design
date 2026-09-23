# Synthesis and Physical Design: current work

The immediate delivery is one reproducible Synopsys synthesis baseline for the chip and every unit, with explicit stubs where RTL is missing.

## Assignment

- [Chip-level synthesis with unit stubs](https://github.com/SiliconBadgers/physical-design/issues/2)
- [Every-unit synthesis targets and reports](https://github.com/SiliconBadgers/physical-design/issues/3)

1. Establish the actual Synopsys tool/version, environment and one library/corner. Keep licensed libraries and site-specific paths outside Git.
2. Inventory every diagram block, including host/register interface, top-level control, four provisional compute blocks, local controllers/datapaths where defined, memory/transfer control and SRAM/buffer wrappers. Record owning repo, source revision, top, parameters and real/stub/black-box status.
3. Provide a chip-top assembly harness and standalone targets for every unit with the same source configuration. Add one aggregate command and isolated run outputs. Demonstrate stub-to-real replacement and the real signed MAC pilot.
4. Report hierarchy/link and constraint checks, netlist, area and timing for the stated configuration. Expose optimized-away stubs and excluded memories; do not present stub-top numbers as full-chip PPA.
5. Make missing sources, unresolved modules and tool/setup failures fail targets and the aggregate result. Record reproducible evidence. Floorplanning, place-and-route, signoff and broad sweeps are outside these first two issues.

## Starting evidence

- [Central diagram](https://github.com/SiliconBadgers/architecture/blob/main/docs/accelerator-diagram.md)
- [Recorded Software profiling package](https://github.com/SiliconBadgers/software/tree/main/experiments/llama-cpp/2026-09-22)

## Artifact locations

| Location | What belongs here |
|---|---|
| [flows/synopsys/](../flows/synopsys/README.md) | Team-owned chip/unit synthesis scripts, unit manifest and source selection for issues #2 and #3. Record tool versions and a single baseline library/corner; no licensed files in Git. |
| [rtl/stubs/](../rtl/stubs/README.md) | Clearly labeled temporary synthesizable stubs, separated from real component RTL. Their ports are proposals; coordinate them with RTL owners. |
| [rtl/wrappers/](../rtl/wrappers/README.md) | Chip assembly and unit wrappers that consume revision-pinned component sources. Do not copy authoritative component implementations here. |
| [constraints/](../constraints/README.md) | Chip and per-unit baseline clocks, I/O assumptions and justified exceptions. Identify unresolved constraints instead of quietly treating them as met. |
| [reports/](../reports/README.md) | Compact curated run summaries and links to evidence, including real/stub/black-box status and unavailable measurements. Generated tool databases/netlists live outside Git unless explicitly reviewed. |

## What runs today

No Synopsys synthesis run is supplied or claimed by this refresh. The chip flow, all-unit runner and reports remain the two team assignments.

These folders organize the work; they do not complete the issues. Use the
existing evidence now and publish useful intermediate results. Arrange a team
meeting this week to divide the work and agree on next steps.

Follow [CONTRIBUTING.md](../CONTRIBUTING.md) before editing or committing.
