# SiliconBadgers PD flow

SiliconBadgers' RTL-to-GDS scripts for the SkyWater 130 nm process. Every track runs the same stages with one set of tools, so a design can go through any of them and the results can be compared.

## Tracks

| Track | Tools | Folder |
|---|---|---|
| A | Open-source: Yosys, OpenROAD, KLayout (reference: OpenROAD-flow-scripts) | [`tracks/a`](tracks/a/track/README.md) |
| B1 | Cadence: Genus, Innovus, Tempus, Quantus, Voltus, Pegasus | [`tracks/b1`](tracks/b1/track/README.md) |
| B2 | Synopsys: Design Compiler, IC Compiler II, StarRC, PrimeTime | [`tracks/b2`](tracks/b2/track/README.md) |

Run every command from your track's folder; build output goes to its `build/` folder:

```
cd tracks/b2       # or tracks/a, tracks/b1
make all DESIGN=gcd
```

Setup, commands and status for a track: `track/README.md` in its folder. [tracks/README.md](tracks/README.md) helps you pick one.

## PDK

Clone the [SiliconBadgers sky130 PDK](https://github.com/ihagedo/silicon-badgers-sky130-pdk) next to this repo:

```
git clone https://github.com/ihagedo/silicon-badgers-sky130-pdk.git
```

Tracks A and B2 use it as it is. Track B1 also needs Cadence's sky130 library and decks, which you add yourself ([Track B1 setup](tracks/b1/track/README.md#cadence-library-and-decks)).

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
| `tracks/<track>/designs/<name>/` | that track's config (`design.mk`) and constraint file for it |

`tile` (the systolic MAC array) places four `sb_sram_256x8` blocks as hard macros. Each track builds `sb_sram_256x8` through the same stages first, then turns it into an abstract (LEF, timing model, GDS, netlist).

## License

Apache-2.0 ([LICENSE](LICENSE)). A few files come from OpenROAD-flow-scripts and keep its BSD 3-Clause license; [NOTICE](NOTICE) lists them.
