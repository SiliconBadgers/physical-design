# Track B1: Cadence tools

The flow on `sky130_scl_9T`, a 9-track sky130 cell library, with Cadence tools. It needs a machine with the tools and their licenses.

Track B1 is the folder `flows/cadence`. Run every command on this page from there; paths are relative to it.

## Tools

| Tool | Stages | Assumed version |
|---|---|---|
| Xcelium (`xrun`, HAL) | `lint`, `sim`, `gls` (with cocotb 2.1.0) | 23.09 or newer |
| Genus | `synth` | 22.1 or newer, Stylus |
| Innovus | `floorplan` `place` `cts` `grt` `route` `finish` `gds` | 22.1 or newer, Stylus |
| Quantus (`qrc`) | extraction in `finish` | 22.1 or newer |
| Tempus | `sta`, sign-off timing in `finish` | 22.1 or newer, Stylus |
| Voltus | IR drop in `finish` | 22.1 or newer, Stylus |
| Pegasus | `drc`, `lvs` | 22.1 or newer |
| Conformal LEC (`lec`) | `lec`, `lec-mutation` | 21.1 or newer |

## Setup

- From the repo root, clone the PDK repo: `git clone https://github.com/ihagedo/silicon-badgers-sky130-pdk.git` (the flow looks for it in `silicon-badgers-sky130-pdk/` there), or set `SB_PDK`. This track uses its `cadence/` folder, which you fill in yourself (below).
- Load the tools and licenses the way your site does it, for example:
  ```
  module load xcelium genus innovus quantus tempus voltus pegasus conformal   # names vary per site
  export CDS_LIC_FILE=<port>@<license server>                                 # or LM_LICENSE_FILE
  ```
  Other command names or a wrapper: `GENUS=`, `INNOVUS=`, `TEMPUS=`, `VOLTUS=`, `PEGASUS=`, `XRUN=`, `LEC=` on the `make` line.
- Python 3.10 with `cocotb==2.1.0` for `make sim` and `make gls`.
- `make info`: every tool found, every PDK file `OK`.


### Cadence library and decks

The PDK repo has no Cadence files: Cadence's sky130 releases can't be redistributed. Copy them from those releases into your PDK clone:

| PDK path | From |
|---|---|
| `cadence/sky130_scl_9T/`, `cadence/sky130_scl_9T_tech/` | the `sky130_scl_9T/` and `sky130_scl_9T_tech/` folders of `sky130_scl_9T_0.1.2.tgz` |
| `cadence/tech/qrcTechFile` | `quantus/extraction/typical/qrcTechFile` in `sky130_release_0.1.0.tgz` |
| `cadence/tech/pegasus/drc/`, `cadence/tech/pegasus/lvs/` | `Sky130_DRC/` and `Sky130_LVS/` in `sky130_release_0.1.0.tgz` |

`flow/platforms/sky130_scl_9T.mk` names every file the track reads, and `make info` checks that each one is there.

## Run

```
make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]
```

| Stage | Tool | Output in `build/<design>/<variant>/` |
|---|---|---|
| `lint`, `sim` | Xcelium HAL, Xcelium + cocotb | `lint.log` (`lint/hal.log`), `results.xml` |
| `synth` | Genus | `netlist.v`, `synth.log`, `synth_*.rpt` |
| `sta` | Tempus | `sta.rpt`, `sta.json` |
| `floorplan` `place` `cts` `grt` `route` | Innovus | `<stage>.db`, `.log`, `.rpt`, `.json` (metrics), `reports/<stage>/` |
| `finish` | Innovus, Quantus, Tempus, Voltus | `finish.db`, `final.v`, `final_logic.v`, `final_lvs.v`, `final_<corner>.spef`, `finish.json`, `finish_sta.rpt`, `ir/` |
| `gds` | Innovus | `final.gds` |
| `drc`, `lvs` | Pegasus | `drc_count.txt`, `drc/`; `lvs.rpt`, `lvs/` |
| `lec` | Conformal | `lec_synth.log` (RTL vs `netlist.v`), `lec_route.log` (`netlist.v` vs routed `final_logic.v`); `lec_<step>.rpt`: PASS line |
| `gls` | Xcelium + cocotb | `gls_results.xml`: the RTL testbench on `final_logic.v` with the cell models; `sim_gls/` |
| `abstract` | Innovus | `abstract/<top>.{lef,gds,v}`, `<top>_lvs.v`, `<top>_<corner>.lib`: the design as a macro (`.v`: routed logic netlist; `_lvs.v`: LVS netlist) |
| `all` | | every stage above |
| `lec-mutation` | Conformal | both LEC steps must fail on broken netlists |

Settings in `designs/<design>/design.mk`, or on the `make` line: `CORE_UTILIZATION`, `ASPECT_RATIO`, `CORE_MARGIN`, `PLACE_DENSITY`, `IO_CONSTRAINTS`, `GPL_TIMING_DRIVEN`, `CTS_BUF_LIST`, `CTS_INV_LIST`, `SKIP_CTS_REPAIR_TIMING`, `PDN_STRAP_PITCH`.
Flow settings: `HAL_ARGS` (`-f flow/scripts/lint/hal_rules.f`: the HAL style rules `lint` turns off; empty runs every rule), `SETUP_CORNERS` (`tt`), `HOLD_CORNERS` (`tt`), `SYNTH_EFFORT`, `EXTRACT_EFFORT` (`signoff`), `SKIP_IR=1`, `DRC_DENSITY=1`, `NCPU`, `LEC_SYNTH_MODE` (`genus`: the dofile Genus wrote; `own`: `lec_synth.do`), `GLS_XRUN_ARGS` (`-seq_udp_delay 50ps`), `SIM_TIMEOUT` (`900`: seconds one `sim` or `gls` run may take; past it the simulator is killed and the stage fails).

## Layout

| Path | |
|---|---|
| `flow/Makefile` | stages and their inputs |
| `flow/platforms/` | platform files from the PDK repo (`sky130_scl_9T.mk`), LEF to Quantus layer names, tie-cell models |
| `flow/scripts/mmmc.tcl` | corners, libraries and SDC for Genus, Innovus and Tempus |
| `flow/scripts/pnr/` | one Innovus script per stage, `power.tcl`, `common.tcl` |
| `flow/scripts/genus/`, `tempus/`, `voltus/`, `pegasus/` | the other tool steps |
| `flow/scripts/lec/` | Conformal dofiles, result check, mutation check |
| `designs/<name>/` | `design.mk`, `constraint.sdc`, `hal_waivers.txt` (this track); `rtl/`, `tb/` are shared, in `flows/designs/<name>/` (`../designs/<name>/`) |

## Macros

- A design lists the designs it uses as hard macros in `design.mk`: `MACROS := sb_sram_256x8`.
- Every stage from `synth` on first runs `make abstract` for each macro (variant `MACRO_VARIANT`, default `base`) in its own make, so knobs on your command line do not reach the macro.
- Placement: rows of macros from the top of the core, `MACRO_CHANNEL` (default 80 um) apart and from the core edge; `MACRO_HALO` (default 10 um) keeps standard cells out around each macro. With macros, the core is sized from the area of every instance and grown until they fit.
- The macro's power pins are its met4 straps (its `pdn.tcl`); the met5 straps of the top grid cross the macro and connect to them. The macro routes up to met4 only (`MACRO_TOP_LAYER` in the platform file).
- The tile reads the macro LEF and timing models in Genus, Innovus and Tempus, merges its GDS, and LVS reads its LVS netlist (`abstract/<macro>_lvs.v`).
- LEC treats the macro as a black box (check the macro itself with `make lec DESIGN=sb_sram_256x8`); GLS simulates its routed netlist (`abstract/<macro>.v`).

## Status

- gcd: written, not yet run on Cadence tools. Checked without them: Tcl, shell and Python syntax, and `make all` with stub tools.
- tile and sb_sram_256x8: written, not yet run on Cadence tools. Checked without them: Tcl syntax, the floorplan and power-grid scripts against mocked commands, and `make` with stub tools (macro first, rebuild scope).
- `lec`, `lec-mutation` and `gls`: written, not yet run on Cadence tools. Checked without them: Tcl syntax, the dofiles against mocked Conformal commands, `make` with stub tools, the mutations on Yosys-mapped `sky130_scl_9T` netlists (each mutant not equivalent), and GLS of those netlists with the PDK cell models in Icarus.
- Not yet: GLS with SDF (wire and cell) delays.

## Notes

- Same metric names as track A, but another library (`sky130_scl_9T`, not `sky130_fd_sc_hd`), so the numbers compare flows, not like for like.
- Timing is signed off at `tt` by default, like track A, so the metrics compare. For full signoff run a variant with `SETUP_CORNERS=ss HOLD_CORNERS="ff tt"` (expect negative setup at `ss` until the clock is recalibrated).
- `grt` is Innovus's early global route (congestion and timing estimate); `route_design` in `route` routes again in full.
- `cts` runs `create_clock_tree_spec` and `ccopt_design` on Innovus releases before 25, and `clock_opt_design` on 25 and newer (on 21.x `clock_opt_design` is a beta feature that builds no clock tree and reports no error). The `SB: cts command` line in `cts.log` names the one used.
- A metric a script cannot read is `null`; the report next to it has the number.
- Cadence tools can exit 0 after a script error, so a stage passes only if its log ends with `SB: <name> done`.
- A stage also fails on any tool error line in its log, even after `SB: <name> done` (a command inside `sb_try` can fail and the script goes on): Innovus, Tempus and Voltus `**ERROR:`, Quantus `ERROR (<ID>) :`, Xcelium `*E,`/`*F,` (`sim`, `gls`; `lint` keeps its own HAL check). `flow/scripts/util/log_check.sh` does it for every stage; a harmless error is waived by its message ID, with a reason, in `flow/scripts/util/log_waivers.txt` (empty today). A failed stage leaves no `<stage>.json` (or other target), so make runs it again.
- `synth_check.py` (in `make synth`) fails when it cannot read one of its report rows. A synthesis wrapper that writes no Genus reports (a stand-in for Genus) may write `synth_check.skip` next to `netlist.v`, one line saying why; the check then prints `synth check SKIPPED` with that line, and still checks `netlist.v` for latch cells. `make synth` deletes the file and the old reports before each run.
- `check_timing` (top of `sta.rpt` and `finish_sta.rpt`) on the tile lists `rst_n` without an input delay and three unconstrained endpoints, all in the reset synchronizer: the `RN` pins of its two flip-flops (recovery/removal, which only `rst_n` reaches; `rst_n` is asynchronous and the SDC false-paths it) and `u_reset_sync/stage1_q_reg/D` (tied to a constant). These are expected. Any other unconstrained endpoint or input without an input delay is a missing constraint.
- With hard macros, the IR drop in `finish` covers the standard cells only: the macro's timing model has no power data and there is no power-grid view of the macro (`build/pgv` has the cells' only), so the macros draw no current in the analysis. Accepted for this flow; the tile's IR numbers leave out its four SRAM blocks.
- `final.v` (with the antenna diodes, which the extracted parasitics include) is for Tempus; `final_logic.v` (no fillers, decaps, antenna diodes or power pins) is for LEC and GLS; LVS uses `final_lvs.v`.
- LEC passes on compare points with none non-equivalent, aborted or unknown (`lec_result.py` reads the `No of ... points` lines). In `lec_route`, key points map by name: Innovus keeps the instance names, so no renaming rules are needed.
- GLS: the cell models have zero delay; `-seq_udp_delay` gives every flip-flop a clock-to-Q delay, so the clock tree cannot race the data (it also turns off the specify blocks). Do not use `-notimingchecks`: it stops the delayed clock and data nets the flip-flop models need.

## First run checklist

The scripts were written against the tool documentation. On the first run on a licensed machine, check these in order:

1. `make info`: every tool found, `qrc` too. Start-up flags: `INNOVUS_FLAGS="-stylus -nowin"` (older releases: `-common_ui`), `TEMPUS_FLAGS` and `VOLTUS_FLAGS="-stylus -no_gui"`. Each tool exits at the end of its script.
2. `make lint`: HAL messages look like `*W,<CODE> (<file>,<line>|<col>): ...` (in xrun's log file, `lint/hal.log`). HAL runs without the style rules in `flow/scripts/lint/hal_rules.f`; waive each other harmless gcd message in `designs/gcd/hal_waivers.txt`, with a reason, until lint passes.
3. `make sim`: both cocotb tests pass in `results.xml`.
4. `make synth`: Genus reads the gzipped Liberty, `mmmc.tcl` and the LEF; no `SB-WARNING` about `hdl_error_on_blackbox`, `use_tiehilo_for_const` or `add_tieoffs`; `synth check PASS` (it fails when it cannot read a report row: then fix the row labels in `synth_check.py`); `grep -c "1'b" build/gcd/base/netlist.v` is 0.
5. `make sta`: `sta.json` has numbers, not `null`. `null` means `report_timing -collection` or the `slack` property differs in this release: fix `sb_slack` in `flow/scripts/util/sb_util.tcl`.
6. `make floorplan`: `create_floorplan -core_density_size`, `add_rings`, `add_stripes` (`-start`, `-create_pins`), `route_special` and the Quantus layer map are accepted. In the GUI (`read_db build/gcd/base/floorplan.db`): a ring, met4 and met5 straps, met1 rails on every row, VDD/VSS pins at the met5 strap ends. The `SB: floorplan_pg.rpt` line (the power grid connectivity check) counts 0 everywhere.
7. `make place cts`: pins on the core edge; `place.json` and `cts.json` have numbers; `reports/<stage>/` has the `time_design` summaries. The cts skew (spread of the register clock-pin arrivals, `arrival_max_rise`/`arrival_min_rise`) is close to `cts_skew_groups.rpt`, and `cts_clock_trees.rpt` (`Clock DAG stats`) counts at least one buffer on gcd (none: no tree was built).
8. `make grt route`: `route_early_global` runs; `route.json` has wirelength, vias and DRC count; the count matches `route_drc.rpt` (else fix the labels in `sb_drc_count`, `common.tcl`); `route_antenna.rpt` is clean (else add diode insertion with the phyCells `ANTENNA` cell).
9. `make finish`: Quantus runs standalone and writes three SPEFs; `finish_sta.log` annotates every net; `finish.json` has every key. Voltus builds `build/pgv/techonly.cl`, finds the VDD/VSS pins (`set_power_pads -format defpin`) and writes `ir/rail/` (`SKIP_IR=1` to go on without it).
10. `make gds`: `write_stream -units 1000` is accepted and the cells in `final.gds` have their layouts.
11. `make drc`: Pegasus accepts the control file and `#DEFINE NODEN`; `drc_count.txt` matches the total in `drc/gcd.drc.sum` (else fix the count in `drc.sh`).
12. `make lvs`: passes on `MATCH` without `MISMATCH` in `lvs/gcd.lvs.rpt`; fix that check in `flow/Makefile` if Pegasus words it otherwise. Decap and tie cells are in the CDL; plain fillers are left out of `final_lvs.v`.
13. Note the gcd WNS and `runtimes.txt`; adjust the 6 ns starting period in `designs/gcd/constraint.sdc` if needed.
14. `make abstract DESIGN=sb_sram_256x8`: `write_timing_model` (or `do_extract_model`) writes three `.lib`; `write_lef_abstract` (`-stripe_pins`, `-pg_pin_layers`, `-specify_top_layer`) writes the met4 straps as `VDD`/`VSS` pins and no met5; `final_lvs.v` has `VDD`/`VSS` ports. In `final.gds` every signal pin has metal on datatype 20 under its datatype-16 shape. The block has no core ring, so its `floorplan_pg.rpt` has dangling rail ends at the core edge only.
15. `make floorplan DESIGN=tile`: the `SB: macro` lines and the GUI show four macros 80 um apart, halos, no rows or met4 straps over them, and met4 to met5 vias on their power pins. The `SB: floorplan_pg.rpt` line counts the problems in `floorplan_pg.rpt`: dangling ends (`IMPVFC-94`) at the macro halos are expected and ignored (the halos cut the met1 rails and met4 straps; each piece still meets a strap). A dangling end elsewhere or any other problem (an open, an unconnected pin) fails this item. Dangling ends at the core edge are expected only in a block without a core ring (`sb_sram_256x8`, item 14). `place_inst`, `create_place_halo -all_blocks`, `create_route_halo`, `cut_rows -area` and `add_stripes -area_blockage` are accepted (no `SB-WARNING`).
16. `make gds lvs DESIGN=tile`: `gds.log` shows how `-uniquify_cell_names` treats the library cells that are in both the cell GDS and the macro GDS; LVS matches with `sb_sram_256x8` as its own cell. If Voltus stops on the macro in `finish` (no power-grid view), run with `SKIP_IR=1`. If it goes on, it leaves the macros out of the IR drop (Notes): `sb_sram_256x8` is in its list of cells without power tables, and the rail statistics show `Macro: ... IR: 0`. That is expected.
17. `make synth`: Genus writes `genus_lec.do` (no `SB-WARNING: write_do_lec failed`). It names `netlist.v` by the path make passed (`lec-mutation` replaces that path with the mutant's) and prints the `No of ... points` lines; if not, use `LEC_SYNTH_MODE=own`.
18. `make finish`: `write_netlist -exclude_leaf_cells -exclude_insts_of_cells` is accepted; `grep -cE '^\s*(FILL|ANTENNA)' build/gcd/base/final_logic.v` is 0, and `final_logic.v` has no `VDD`/`VSS` ports and no `module` of a library cell or macro.
19. `make lec`: Conformal starts with `LEC_FLAGS="-xl -nogui"`, reads the gzipped Liberty and exits by itself; `lec_synth.log` and `lec_route.log` end with the four `No of ... points` lines and both `lec_*.rpt` say PASS. An `SB-WARNING` in a log names a command this release words otherwise (`add_black_box`, `set_parallel_option`, `report_unmapped_points`, `set_flatten_model`, `analyze_abort`). Run gcd with `LEC_SYNTH_MODE=own` too.
20. `make lec DESIGN=sb_sram_256x8`, then `DESIGN=tile`: `report_black_box` lists `sb_sram_256x8` on both sides (four instances in the tile), and `lec_route.log` has no unmapped flip-flops. Note the tile's `lec_route` run time (track A needed named match points to make its gate-vs-gate check fast); if it is slow or aborts, compare module by module (`write_hier_compare_dofile`, `run_hier_compare`), since both netlists keep the Genus hierarchy.
21. `make lec-mutation` for the three designs: `4/4 caught`, logs in `lec_mutation/`.
22. `make gls DESIGN=gcd`, then `DESIGN=tile`: `xrun` accepts `-seq_udp_delay 50ps` (else set `GLS_XRUN_ARGS`); `sim_gls/xrun_build.log` has no `*E` (a missing module means `final_logic.v` kept a physical cell; a module defined twice means the tile and macro netlists share a Genus module name); 2/2 and 3/3 tests pass.

Back: [README.md](../../README.md)
