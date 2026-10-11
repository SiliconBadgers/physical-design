# Track B2: Synopsys tools

The flow on sky130hd with Synopsys tools, and KLayout for DRC and LVS. Same stages, build layout and metric names as Track A, so the two tracks can be compared run for run.

## Tools

| Tool | Command | Used for |
|---|---|---|
| VC SpyGlass (optional), else VCS | `vc_static_shell`, `vcs +lint=all` | `lint` |
| VCS with cocotb | `vcs` | `sim`, `gls` |
| Design Compiler | `dc_shell` | `synth` |
| PrimeTime | `pt_shell` | `sta`, and sign-off timing in `finish` |
| Formality | `fm_shell` | `lec`, `lec-mutation` |
| IC Compiler II | `icc2_shell` | `floorplan` to `finish`, `gds` |
| StarRC | `StarXtract` | extraction in `finish` |
| KLayout | `klayout` | `drc`, `lvs` with the open sky130hd decks (no IC Validator decks exist for sky130) |
| Library Compiler, IC Compiler II Library Manager, `grdgenxo` | `lc_shell`, `icc2_lm_shell`, `grdgenxo` | `make_views.sh` (once); `lc_shell` and `icc2_lm_shell` also in `abstract` |

Assumed versions: the V-2023.12 releases or newer of Design Compiler, PrimeTime, IC Compiler II, StarRC, Formality and VCS (app-option names change between releases; see the checklist). KLayout 0.30.12, cocotb 2.1.0 and Python 3.9 or newer, as Track A.

## Setup

- Load the Synopsys tools the way your site does it, then check: `which dc_shell pt_shell icc2_shell StarXtract fm_shell vcs klayout`.
- Clone the PDK repo next to this repo under that folder name (`git clone <PDK repo URL> silicon-badgers-sky130-pdk`), or set `SB_PDK`. This track uses its `synopsys/` folder, the DRC and LVS decks in `open/sky130hd/` and the cell simulation models in `open/verilog/`.
- Build the Synopsys views once per PDK checkout: `$SB_PDK/synopsys/make_views.sh`. It writes `synopsys/views/`: three `.db` files (ss, tt, ff), the `.tluplus` and `.nxtgrd` RC tables and `sky130_fd_sc_hd.ndm`. Without them `make synth` and later stages stop with this instruction. `make info` shows whether they are there.
- `pip install cocotb==2.1.0` for `make sim` and `make gls`.

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
| `finish` | IC Compiler II, StarRC, PrimeTime | `final.v`, `final_logic.v`, `final_lvs.v`, `final.def`, `final.spef`, `signoff_<corner>.rpt`, `finish.json` |
| `gds`, `drc`, `lvs` | IC Compiler II, KLayout | `final.gds`, `drc.lyrdb`, `lvs.lvsdb` |
| `lec` | Formality | `lec_synth.log` (RTL vs `netlist.v`, with `synth.svf`), `lec_route.log` (`netlist.v` vs `final_logic.v`), `lec_<step>_{unmatched,blackboxes,failing}.rpt` |
| `gls` | VCS and cocotb | `gls_results.xml`: the RTL testbench on `final_logic.v` with the cell models |
| `abstract` | IC Compiler II, PrimeTime, Library Compiler, KLayout | `abstract/<top>.{lef,lib,gds,cdl,v}`, `<top>_<corner>.db`, `<top>.ndm`: the design as a macro |
| `all` | | every stage above (not `abstract`) |
| `lec-mutation` | Formality | both LEC steps must fail on broken netlists (`lec_mutation/`) |

- Sign-off corners: `tt` for setup and hold by default (`SETUP_CORNERS=tt`, `HOLD_CORNERS=tt`), like track A, so the metrics compare. IC Compiler II fixes setup and hold in those scenarios.
- `finish.json` gets its timing from PrimeTime with the StarRC parasitics (worst over the corners); area and utilization come from IC Compiler II. A value a script could not read is `null`.
- `final_logic.v` is `final.v` (the PrimeTime netlist) without antenna diodes: the logic netlist for LEC and GLS. LVS uses `final_lvs.v`.
- `lec_route` uses no SVF: IC Compiler II keeps the flip-flop, port and macro instance names of `netlist.v`, and Formality pairs those by name; the buffers, resized cells, swapped pins and tie cells from place and route sit inside the logic cones between them.
- GLS uses the SkyWater models with `FUNCTIONAL` and `UNIT_DELAY=#1` (a 1 ns flip-flop delay, no other cell delays).
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
| `GLS_VCS_ARGS` | none | extra VCS compile options for `gls` |
| `SIM_TIMEOUT` | `900` | seconds one `sim` or `gls` run may take; past it the simulator is killed and the stage fails (a hang is often a combinational loop) |
| `MACRO_HALO`, `MACRO_CHANNEL` | `10`, `80` | um: standard-cell keep-out around each macro; space between macros and to the core edge |
| `MACRO_VARIANT` | `base` | variant of the macros' builds |

## Layout

| Path | |
|---|---|
| `flow/Makefile` | stages and their inputs |
| `flow/platforms/sky130hd.mk` | PDK files, corners and cells |
| `flow/scripts/` | one folder per tool: `dc`, `pt`, `icc2`, `starrc`, `lc`, `fm`, `klayout`, `lint`, `sim`; `util/` has the shell wrapper and metrics procs |
| `designs/<name>/` | `design.mk`, `constraint.sdc` (this track); `rtl/`, `tb/` (shared) |

## Macros

- A design lists the designs it uses as hard macros in `design.mk`: `MACROS := sb_sram_256x8`.
- Every stage first runs `make abstract` for each macro (variant `MACRO_VARIANT`) in its own make, so knobs on your command line do not reach the macro.
- `abstract`: LEF from the IC Compiler II frame (`create_frame -block_all used_layers`), a PrimeTime `extract_model` per corner with the StarRC parasitics (`<top>.lib` is tt), compiled to `.db`, and an IC Compiler II library (`.ndm`) from both. Design Compiler and PrimeTime read the `.db`, IC Compiler II the `.ndm`.
- Placement (`macro_place.tcl`): rows from the top-left of the core, `MACRO_CHANNEL` apart and from the core edge, on the met2/met4 and met3/met5 track grid; a hard keep-out margin of `MACRO_HALO`.
- The macro routes up to met4 (`MAX_ROUTING_LAYER` in its `design.mk`); its met4 straps are its power pins. The parent's met1 rails and met4 straps stop at the macro, its met5 straps cross it and connect to those pins.
- Every `final.gds` gets drawing metal under its top-level pin shapes (`pin_metal.py`), so a wire that ends at a macro pin connects.
- LEC treats the macro as a black box (its `.db` has no logic; check the macro itself with `make lec DESIGN=sb_sram_256x8`); GLS simulates its routed netlist (`abstract/<macro>.v`).

## Notes

- A stage that runs Design Compiler, PrimeTime, IC Compiler II, its Library Manager, Library Compiler or Formality fails when its log has a line that starts with `Error:`, even if the tool exits normally: some commands print an error and go on (`write_gds` with a layer map it cannot read, `create_terminal`). StarRC's `extract.log` is checked for `ERROR`. The check is `flow/scripts/util/check_log.sh`; a harmless message can be waived there by its ID, with the reason (none is). `lec-mutation` is not checked this way: its mutants must fail. KLayout exits with an error status on its own.

## Status

- Run on Synopsys tools (CAE lab, 2026-10-11): Design Compiler, PrimeTime, Formality, Library Compiler and VCS Y-2026.03, IC Compiler II X-2025.06-SP3, StarRC 2026.03, KLayout 0.30.12; `lint` with VCS (no VC SpyGlass there). Needs the PDK at 6ba406e or later (IC Compiler II layer map, tap and fill cells in the NDM, hole-area rules in the `.tf`).
- gcd (6.2 ns, tt): every stage passes; 0 DRC, LVS match, LEC passes, GLS 2/2, `lec-mutation` 4/4. Sign-off setup slack −0.06 ns on 4 paths, hold +0.51 ns.
- gcd full signoff (`SETUP_CORNERS=ss HOLD_CORNERS=ff`): every stage passes; ss setup −0.13 ns on 10 paths, ff hold +0.36 ns. With 6.0 ns it was −0.11 ns: the tools spend the extra time on smaller cells.
- IC Compiler II (TLU+) sees 0.00 to +0.02 ns where PrimeTime with StarRC sees −0.06 to −0.13 ns, so gcd's sign-off setup slack stays slightly negative.
- `sb_sram_256x8` (`make abstract`): passes; setup +3.68 ns; 0 DRC, LVS match, LEC passes, `lec-mutation` 4/4.
- tile (four macros, 65 MHz): every stage passes; setup +1.08 ns (Track A +1.02 ns), hold +0.02 ns; 0 DRC, LVS match, LEC passes (the four macros are the only black boxes), GLS 3/3, `lec-mutation` 4/4. KLayout LVS takes about 12 minutes.
- Not yet: IR drop (needs a rail analysis tool and rail views of the cells).

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
10. `make finish`: `final_lvs.v` has power pins and the tap and filler cells, `final.v` has neither; `final_logic.v` also has no `diode_2` cells and `finish.log` has no `final_logic.v keeps the antenna diodes` warning (`write_verilog -exclude diode_cells`); `extract.log` maps every LEF layer; `signoff_ss.rpt` shows every net annotated.
11. `make gds`: `write_gds` accepts the layer map, and the GDS has pin labels on datatype 5 (met1 = 68/5), which KLayout LVS reads. If LVS fails on pins, run `make lvs GDS_TOOL=klayout` to tell a layer-map problem from a netlist problem.
12. `make drc lvs`: 0 violations, netlists match.
13. Compare `build/gcd/<variant>/*.json` with Track A. The gcd clock is 6.2 ns, recalibrated at ss on the first run (Track A's 6 ns missed ss by 0.11 ns); recalibrate again if your tools differ, and update `constraint.sdc` and this page.
14. `make abstract DESIGN=sb_sram_256x8`: `floorplan.log` has no `create_terminal` error and `abstract.log` passes the LEF check (VDD and VSS pins on met4); `abstract/<top>_<corner>.lib` has bus pins and the cell `sb_sram_256x8`; `abstract_ndm.log` has no `check_workspace` errors (the LEF and `.db` pins agree).
15. `make floorplan DESIGN=tile`: the macros link from the `.ndm`; `floorplan.rpt` shows no floating macro power pins (`check_pg_connectivity`), met4 straps and rails stop at the macros and met5 crosses them; `macro_place.tcl` placed four macros.
16. `make lvs DESIGN=tile`: `write_gds` merges the macro GDS; netlists match. If not, try `GDS_TOOL=klayout` on the macro (`make abstract DESIGN=sb_sram_256x8 GDS_TOOL=klayout`) and on the tile.
17. `make lec`: `fm_shell` runs `util/run.tcl` (`source -echo`) and exits by itself; `read_sverilog -r -vcs "+incdir+..."` reads the RTL; the `SB: lec_<step>: PASS` line agrees with `Verification SUCCEEDED` in the log (`lec.tcl` takes a `verify` return value of 1 as a pass, and 0 from a read or `set_top` as a failure).
18. `lec_<step>_unmatched.rpt` lists no flip-flops or ports. If `lec_route` has unmatched flip-flops, IC Compiler II renamed or merged them: give `lec_route` an SVF from IC Compiler II.
19. `make lec DESIGN=tile`: `lec_synth_blackboxes.rpt` and `lec_route_blackboxes.rpt` list the four `sb_sram_256x8` instances and nothing else (the macro `.db` from `extract_model` has no function); `make lec DESIGN=sb_sram_256x8` passes; `runtimes.txt` shows how long `lec_route` takes on the tile.
20. `make lec-mutation` on gcd, `sb_sram_256x8` and the tile: 4/4 caught. The script finds instances in the Design Compiler and IC Compiler II spellings (`.A(n1)` and `.A ( n1 )`) and looks for `Verification FAILED` at the start of a line; a `no nand2 cell` or `fewer than two flip-flops` stop means the netlist is spelled another way.
21. `make gls`: VCS compiles the cell models with `-sverilog` (always set by cocotb's VCS runner), `+define+FUNCTIONAL +define+UNIT_DELAY=#1` and `-timescale=1ns/1ps`, and passes gcd 2/2 and the tile 3/3. If VCS stops in `primitives.v` or `sky130_fd_sc_hd.v`, try options through `GLS_VCS_ARGS` (not tried: `+verilog2001ext+.v` to read `.v` files as Verilog-2001, `-override_timescale=1ns/1ps`).

Back: [README.md](../README.md)
