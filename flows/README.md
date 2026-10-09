# SiliconBadgers PD flow

The team's own RTL-to-GDS scripts, maintained by mentors. Every track branch runs the same stages with one set of tools, so a design can go through any of them and the results can be compared.

## Tracks

| Track | Tools | Branch |
|---|---|---|
| A | Open-source: Yosys, OpenROAD, KLayout (reference: OpenROAD-flow-scripts) | `track-a` |
| B1 | Cadence: Genus, Innovus, Tempus, Quantus, Voltus, Pegasus | `track-b1` |
| B2 | Synopsys: Design Compiler, IC Compiler II, StarRC, PrimeTime | `track-b2` |

```
git checkout track-a       # or track-b1, track-b2
```

Setup, commands and status for a track: `track/README.md` on its branch.

## Stages

Every track has these `make` targets: `make <stage> DESIGN=<design>`.

| Stage | What it does | Check |
|---|---|---|
| `lint`, `sim` | rule checks and simulation of the RTL | no lint errors; tests pass |
| `synth` | RTL to a gate-level netlist | no latches, loops or missing cells |
| `sta` | timing of the netlist before layout | setup and hold slack ≥ 0 |
| `floorplan` | die and core size, rows, power grid | grid connects to every row |
| `place` | put every cell on a legal site | no overlaps; timing still met |
| `cts` | build the clock tree, fix hold | skew small; hold slack ≥ 0 |
| `grt`, `route` | global then detailed routing | 0 routing violations, no antenna violations |
| `finish` | fill cells, extraction, final timing and IR drop | setup and hold slack ≥ 0 with extracted wires |
| `gds`, `drc`, `lvs` | final layout file and its signoff checks | 0 DRC errors; layout matches netlist |

Each stage writes a metrics file with the same key names in every track (for example `finish__timing__setup__ws`), so results line up across tracks.

## Designs

| Path | What |
|---|---|
| `designs/<name>/rtl/` | the RTL (shared by every track) |
| `designs/<name>/tb/` | its simulation test |

Each track adds its own config and constraint file next to them.
