# Track B2: Synopsys tools

The flow on sky130hd with Synopsys tools, and KLayout for DRC and LVS. Same stages, build layout and metric names as Track A, so the two tracks can be compared run for run.

## Tools

| Tool | Command | Used for |
|---|---|---|
| VC SpyGlass (optional), else VCS | `vc_static_shell`, `vcs +lint=all` | `lint` |
| VCS with cocotb | `vcs` | `sim` |
| Design Compiler | `dc_shell` | `synth` |
| PrimeTime | `pt_shell` | `sta`, and sign-off timing in `finish` |
| IC Compiler II | `icc2_shell` | `floorplan` to `finish`, `gds` |
| StarRC | `StarXtract` | extraction in `finish` |
| KLayout | `klayout` | `drc`, `lvs` with the open sky130hd decks (no IC Validator decks exist for sky130) |
| Library Compiler, IC Compiler II Library Manager, `grdgenxo` | `lc_shell`, `icc2_lm_shell`, `grdgenxo` | `make_views.sh` (once); `lc_shell` and `icc2_lm_shell` also in `abstract` |

Assumed versions: the V-2023.12 releases or newer of Design Compiler, PrimeTime, IC Compiler II, StarRC and VCS (app-option names change between releases; see the checklist). KLayout 0.30.12, cocotb 2.1.0 and Python 3.9 or newer, as Track A.

## Setup

- Load the Synopsys tools the way your site does it, then check: `which dc_shell pt_shell icc2_shell StarXtract vcs klayout`.
- Clone `silicon-badgers-sky130-pdk` next to this repo, or set `SB_PDK`. This track uses its `synopsys/` folder, and the DRC and LVS decks in `open/sky130hd/`.
- Build the Synopsys views once per PDK checkout: `$SB_PDK/synopsys/make_views.sh`. It writes `synopsys/views/`: three `.db` files (ss, tt, ff), the `.tluplus` and `.nxtgrd` RC tables and `sky130_fd_sc_hd.ndm`. Without them `make synth` and later stages stop with this instruction. `make info` shows whether they are there.
- `pip install cocotb==2.1.0` for `make sim`.

## Run

```
make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]
```

| Stage | Tool | Output in `build/<design>/<variant>/` |
|---|---|---|
| `lint`, `sim` | VC SpyGlass or VCS; VCS and cocotb | `lint.log`, `results.xml` |
| `synth` | Design Compiler, at the first setup corner | `netlist.v`, `synth.log`, `synth_*.rpt` |
| `sta` | PrimeTime, at each setup and hold corner | `sta_<corner>.rpt`, `.json` |
| `floorplan` `place` `cts` `grt` `route` | IC Compiler II | checkpoint `icc2/<stage>/<top>.nlib`, `<stage>.log`, `.rpt`, `.json` (metrics) |
| `finish` | IC Compiler II, StarRC, PrimeTime | `final.v`, `final_lvs.v`, `final.def`, `final.spef`, `signoff_<corner>.rpt`, `finish.json` |
| `gds`, `drc`, `lvs` | IC Compiler II, KLayout | `final.gds`, `drc.lyrdb`, `lvs.lvsdb` |
| `abstract` | IC Compiler II, PrimeTime, Library Compiler, KLayout | `abstract/<top>.{lef,lib,gds,cdl}`, `<top>_<corner>.db`, `<top>.ndm`: the design as a macro |
| `all` | | every stage above (not `abstract`) |

- Sign-off corners: `tt` for setup and hold by default (`SETUP_CORNERS=tt`, `HOLD_CORNERS=tt`), like track A, so the metrics compare. IC Compiler II fixes setup and hold in those scenarios.
- `finish.json` gets its timing from PrimeTime with the StarRC parasitics (worst over the corners); area and utilization come from IC Compiler II. A value a script could not read is `null`.
- Each stage copies the previous checkpoint before changing it, so any stage can be reopened: `icc2_shell`, then `open_lib build/gcd/base/icc2/cts/gcd.nlib; open_block gcd`.

| Variable | Default | |
|---|---|---|
| `SETUP_CORNERS`, `HOLD_CORNERS` | `tt`, `tt` | sign-off corners: `ss`, `tt` or `ff` |
| `CORE_UTILIZATION` `ASPECT_RATIO` `CORE_MARGIN` `PLACE_DENSITY` | `design.mk` | floorplan and placement |
| `CTS_BUF_LIST` | `clkbuf_4 clkbuf_8 clkbuf_16` | cells the clock tree may use; empty = the tool picks |
| `GPL_TIMING_DRIVEN`, `GPL_ROUTABILITY_DRIVEN` | `1` | `create_placement -timing_driven`, `-congestion` |
| `SKIP_CTS_REPAIR_TIMING` | `0` | `1` = no setup and hold repair after the clock tree |
| `IO_CONSTRAINTS`, `PDN_TCL` | none, `flow/scripts/icc2/pdn.tcl` | pin constraints and power grid (IC Compiler II Tcl) |
| `DC_COMPILE` `SYNTH_FLATTEN` `SYNTH_RETIME` | `compile_ultra` `1` `0` | synthesis |
| `GDS_TOOL` | `icc2` | `klayout` merges `final.def` with the cell GDS instead of `write_gds` |
| `LINT_TOOL`, `CORES` | `auto`, `4` | `vc` or `vcs`; CPU cores per tool |
| `MACRO_HALO`, `MACRO_CHANNEL` | `10`, `80` | um: standard-cell keep-out around each macro; space between macros and to the core edge |
| `MACRO_VARIANT` | `base` | variant of the macros' builds |

## Layout

| Path | |
|---|---|
| `flow/Makefile` | stages and their inputs |
| `flow/platforms/sky130hd.mk` | PDK files, corners and cells |
| `flow/scripts/` | one folder per tool: `dc`, `pt`, `icc2`, `starrc`, `lc`, `klayout`, `lint`, `sim`; `util/` has the shell wrapper and metrics procs |
| `designs/<name>/` | `design.mk`, `constraint.sdc` (this track); `rtl/`, `tb/` (shared) |

## Macros

- A design lists the designs it uses as hard macros in `design.mk`: `MACROS := sb_sram_256x8`.
- Every stage first runs `make abstract` for each macro (variant `MACRO_VARIANT`) in its own make, so knobs on your command line do not reach the macro.
- `abstract`: LEF from the IC Compiler II frame (`create_frame -block_all used_layers`), a PrimeTime `extract_model` per corner with the StarRC parasitics (`<top>.lib` is tt), compiled to `.db`, and an IC Compiler II library (`.ndm`) from both. Design Compiler and PrimeTime read the `.db`, IC Compiler II the `.ndm`.
- Placement (`macro_place.tcl`): rows from the top-left of the core, `MACRO_CHANNEL` apart and from the core edge, on the met2/met4 and met3/met5 track grid; a hard keep-out margin of `MACRO_HALO`.
- The macro routes up to met4 (`MAX_ROUTING_LAYER` in its `design.mk`); its met4 straps are its power pins. The parent's met1 rails and met4 straps stop at the macro, its met5 straps cross it and connect to those pins.
- Every `final.gds` gets drawing metal under its top-level pin shapes (`pin_metal.py`), so a wire that ends at a macro pin connects.

## Status

- Written, not yet run on Synopsys tools.
- Checked without them: Tcl, shell and Python syntax; `make all DESIGN=gcd` with stub tools (every stage, reruns, variants, a failing stage); the KLayout steps for real on Track A's gcd layout (0 DRC violations, LVS match through `v2cdl.py`, also with `GDS_TOOL=klayout`).
- The 6 ns clock comes from Track A, which signs off at tt. Track A's routed gcd timed at ss with the same Liberty files has −3.2 ns setup slack, so expect negative setup slack in a full-signoff variant (`SETUP_CORNERS=ss HOLD_CORNERS=ff`) until the clock is recalibrated.
- The tile (`DESIGN=tile`, four `sb_sram_256x8` macros): written, not yet run on Synopsys tools. Checked with stub tools (macro build first, reruns, knob isolation); the KLayout steps for real on Track A's tile and block layouts (LVS match with the macro; without `pin_metal.py` the macro does not match).
- Not yet: LEC, IR drop (needs a rail analysis tool and rail views of the cells).

## First run checklist

1. `make info` finds the views; `make synth`: `dc_shell` exits by itself, `synth.log` has no `Error`, `synth_latches.rpt` says 0 and `synth_loops.rpt` is a loop report (`report_timing -loops`).
2. Design Compiler, PrimeTime and IC Compiler II read `constraint.sdc` without errors (it uses `remove_from_collection`).
3. `make sta`: `sta_ss.json` and `sta_ff.json` have numbers, not `null` (`get_timing_paths -slack_lesser_than`).
4. `make floorplan`: the `SB: rows use site` line names the cells' site; `scenarios.rpt` shows each scenario on its corner's library (picked by `set_voltage` and `set_temperature`); `read_parasitic_tech` maps met1 to met5 without warnings.
5. Any `SB: warning: app option ... not set` line: the option has another name in your release. Fix it in the stage script.
6. `ASPECT_RATIO=2` gives a core twice as tall as wide; if it is twice as wide, swap the `-side_ratio` numbers in `floorplan.tcl`.
7. `floorplan.json` core area and utilization match `report_utilization` in `floorplan.rpt` (`get_core_area` boundary; instance area counts tap cells, not fillers, as OpenROAD does).
8. `cts.json` skew is not `null` and is close to `report_clock_qor` in `cts.rpt` (timing-path attributes `startpoint_clock_latency`, `endpoint_clock_latency`).
9. `make route`: `route_track` starts from the global route saved by `grt`; `route_drc.rpt` has the `Total Wire Length`, `Total Number of Contacts` and `Total number of DRCs` lines that `route.json` reads (else fix the patterns in `sb_route_metrics`); `route.log` has no `antenna rules not loaded` line.
10. `make finish`: `final_lvs.v` has power pins and the tap and filler cells, `final.v` has neither; `extract.log` maps every LEF layer; `signoff_ss.rpt` shows every net annotated.
11. `make gds`: `write_gds` accepts the layer map, and the GDS has pin labels on datatype 5 (met1 = 68/5), which KLayout LVS reads. If LVS fails on pins, run `make lvs GDS_TOOL=klayout` to tell a layer-map problem from a netlist problem.
12. `make drc lvs`: 0 violations, netlists match.
13. Compare `build/gcd/<variant>/*.json` with Track A, then recalibrate the clock at ss and update `constraint.sdc` and this page.
14. `make abstract DESIGN=sb_sram_256x8`: `floorplan.log` has no `create_terminal` error and `abstract.log` passes the LEF check (VDD and VSS pins on met4); `abstract/<top>_<corner>.lib` has bus pins and the cell `sb_sram_256x8`; `abstract_ndm.log` has no `check_workspace` errors (the LEF and `.db` pins agree).
15. `make floorplan DESIGN=tile`: the macros link from the `.ndm`; `floorplan.rpt` shows no floating macro power pins (`check_pg_connectivity`), met4 straps and rails stop at the macros and met5 crosses them; `macro_place.tcl` placed four macros.
16. `make lvs DESIGN=tile`: `write_gds` merges the macro GDS; netlists match. If not, try `GDS_TOOL=klayout` on the macro (`make abstract DESIGN=sb_sram_256x8 GDS_TOOL=klayout`) and on the tile.

Back: [README.md](../README.md)
