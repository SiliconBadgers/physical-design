# Track A: open-source tools

The flow on sky130hd with Yosys, OpenROAD and KLayout. OpenROAD-flow-scripts (ORFS) run on the same netlist is the reference (`make compare`).

## Setup

- Tools at the versions in `tools.lock`. On cyrus: `. ../tools/src/toolenv.sh; . ../tools/src/pdenv.sh`.
- Clone `silicon-badgers-sky130-pdk` next to this repo, or set `SB_PDK`. This track uses its `open/sky130hd` folder.
- `make compare` also needs an ORFS checkout at the `tools.lock` commit (`ORFS=<path>`).

## Run

```
make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]
```

| Stage | Tool | Output in `build/<design>/<variant>/` |
|---|---|---|
| `lint`, `sim` | Verilator, cocotb | `lint.log`, `results.xml` |
| `synth`, `sta` | Yosys, OpenSTA | `netlist.v`, `sta_tt.rpt` |
| `floorplan` `place` `cts` `grt` `route` `finish` | OpenROAD | `<stage>.odb`, `.log`, `.json` (metrics), `.rpt` |
| `gds`, `drc`, `lvs` | KLayout | `final.gds`, `drc.lyrdb`, `lvs.lvsdb` |
| `all` | | every stage above |
| `compare` | ORFS | both flows' metrics per stage; ORFS run in `orfs/` |

## Layout

| Path | |
|---|---|
| `flow/Makefile` | stages and their inputs |
| `flow/platforms/sky130hd.mk` | platform files from the PDK repo |
| `flow/scripts/pnr/` | one OpenROAD script per stage, `gds.py` |
| `designs/<name>/` | `design.mk`, `constraint.sdc`, `lint_waivers.vlt` (this track); `rtl/`, `tb/` (shared) |

## Status

- gcd: every stage passes (0 DRC, LVS match); setup slack and area at or better than ORFS on the same netlist.
- Not yet: designs with macros (the tile), LEC and GLS on the routed netlist.

## Notes

- `extract_parasitics` removes the router's min-area patches from the database, so `finish.tcl` writes the layout before extracting.
- Cells added after the floorplan need `global_connect` before the outputs are written, or LVS fails on their power pins.
- Synthesis-only don't-use cells (`DONT_USE`) include clock buffers; place and route uses `PNR_DONT_USE`.

Back: [README.md](../README.md)
