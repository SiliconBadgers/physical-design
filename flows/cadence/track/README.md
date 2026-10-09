# Track B1: Cadence tools

The flow on `sky130_scl_9T`, a 9-track sky130 cell library, with Cadence tools. It needs a machine with the tools and their licenses.

## Tools

| Tool | Stages | Assumed version |
|---|---|---|
| Xcelium (`xrun`, HAL) | `lint`, `sim` (with cocotb 2.1.0) | 23.09 or newer |
| Genus | `synth` | 22.1 or newer, Stylus |
| Innovus | `floorplan` `place` `cts` `grt` `route` `finish` `gds` | 22.1 or newer, Stylus |
| Quantus (`qrc`) | extraction in `finish` | 22.1 or newer |
| Tempus | `sta`, sign-off timing in `finish` | 22.1 or newer, Stylus |
| Voltus | IR drop in `finish` | 22.1 or newer, Stylus |
| Pegasus | `drc`, `lvs` | 22.1 or newer |

## Setup

- Clone `silicon-badgers-sky130-pdk` next to this repo, or set `SB_PDK`. This track uses its `cadence/` folder.
- Load the tools and licenses the way your site does it, for example:
  ```
  module load xcelium genus innovus quantus tempus voltus pegasus   # names vary per site
  export CDS_LIC_FILE=<port>@<license server>                       # or LM_LICENSE_FILE
  ```
  Other command names or a wrapper: `GENUS=`, `INNOVUS=`, `TEMPUS=`, `VOLTUS=`, `PEGASUS=`, `XRUN=` on the `make` line.
- Python 3.10 with `cocotb==2.1.0` for `make sim`.
- `make info`: every tool found, every PDK file `OK`.

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
| `finish` | Innovus, Quantus, Tempus, Voltus | `finish.db`, `final.v`, `final_lvs.v`, `final_<corner>.spef`, `finish.json`, `finish_sta.rpt`, `ir/` |
| `gds` | Innovus | `final.gds` |
| `drc`, `lvs` | Pegasus | `drc_count.txt`, `drc/`; `lvs.rpt`, `lvs/` |
| `all` | | every stage above |

Settings in `designs/<design>/design.mk`, or on the `make` line: `CORE_UTILIZATION`, `ASPECT_RATIO`, `CORE_MARGIN`, `PLACE_DENSITY`, `IO_CONSTRAINTS`, `GPL_TIMING_DRIVEN`, `CTS_BUF_LIST`, `CTS_INV_LIST`, `SKIP_CTS_REPAIR_TIMING`, `PDN_STRAP_PITCH`.
Flow settings: `SETUP_CORNERS` (`tt`), `HOLD_CORNERS` (`tt`), `SYNTH_EFFORT`, `EXTRACT_EFFORT` (`signoff`), `SKIP_IR=1`, `DRC_DENSITY=1`, `NCPU`.

## Layout

| Path | |
|---|---|
| `flow/Makefile` | stages and their inputs |
| `flow/platforms/` | platform files from the PDK repo (`sky130_scl_9T.mk`), LEF to Quantus layer names |
| `flow/scripts/mmmc.tcl` | corners, libraries and SDC for Genus, Innovus and Tempus |
| `flow/scripts/pnr/` | one Innovus script per stage, `power.tcl`, `common.tcl` |
| `flow/scripts/genus/`, `tempus/`, `voltus/`, `pegasus/` | the other tool steps |
| `designs/<name>/` | `design.mk`, `constraint.sdc`, `hal_waivers.txt` (this track); `rtl/`, `tb/` (shared) |

## Status

- gcd: written, not yet run on Cadence tools. Checked without them: Tcl, shell and Python syntax, and `make all` with stub tools.
- Not yet: designs with macros, LEC and GLS.

## Notes

- Same metric names as track A, but another library (`sky130_scl_9T`, not `sky130_fd_sc_hd`), so the numbers compare flows, not like for like.
- Timing is signed off at `tt` by default, like track A, so the metrics compare. For full signoff run a variant with `SETUP_CORNERS=ss HOLD_CORNERS="ff tt"` (expect negative setup at `ss` until the clock is recalibrated).
- `grt` is Innovus's early global route (congestion and timing estimate); `route_design` in `route` routes again in full.
- A metric a script cannot read is `null`; the report next to it has the number.
- Cadence tools can exit 0 after a script error, so a stage passes only if its log ends with `SB: <name> done`.

## First run checklist

The scripts were written against the tool documentation. On the first run on a licensed machine, check these in order:

1. `make info`: every tool found, `qrc` too. Start-up flags: `INNOVUS_FLAGS="-stylus -nowin"` (older releases: `-common_ui`), `TEMPUS_FLAGS` and `VOLTUS_FLAGS="-stylus -no_gui"`. Each tool exits at the end of its script.
2. `make lint`: HAL messages look like `*W,<CODE> (<file>,<line>|<col>): ...`. Waive each harmless gcd warning in `designs/gcd/hal_waivers.txt`, with a reason, until lint passes.
3. `make sim`: both cocotb tests pass in `results.xml`.
4. `make synth`: Genus reads the gzipped Liberty, `mmmc.tcl` and the LEF; no `SB-WARNING` about `hdl_error_on_blackbox`, `use_tiehilo_for_const` or `add_tieoffs`; `synth check PASS` without "could not read" warnings (else fix the row labels in `synth_check.py`); `grep -c "1'b" build/gcd/base/netlist.v` is 0.
5. `make sta`: `sta.json` has numbers, not `null`. `null` means `report_timing -collection` or the `slack` property differs in this release: fix `sb_slack` in `flow/scripts/util/sb_util.tcl`.
6. `make floorplan`: `create_floorplan -core_density_size`, `add_rings`, `add_stripes` (`-start`, `-create_pins`), `route_special` and the Quantus layer map are accepted. In the GUI (`read_db build/gcd/base/floorplan.db`): a ring, met4 and met5 straps, met1 rails on every row, VDD/VSS pins at the met5 strap ends.
7. `make place cts`: pins on the core edge; `place.json` and `cts.json` have numbers; `reports/<stage>/` has the `time_design` summaries. The cts skew (spread of the register clock-pin arrivals, `arrival_max_rise`/`arrival_min_rise`) is close to `cts_skew_groups.rpt`.
8. `make grt route`: `route_early_global` runs; `route.json` has wirelength, vias and DRC count; the count matches `route_drc.rpt` (else fix the labels in `sb_drc_count`, `common.tcl`); `route_antenna.rpt` is clean (else add diode insertion with the phyCells `ANTENNA` cell).
9. `make finish`: Quantus runs standalone and writes three SPEFs; `finish_sta.log` annotates every net; `finish.json` has every key. Voltus builds `build/pgv/techonly.cl`, finds the VDD/VSS pins (`set_power_pads -format defpin`) and writes `ir/rail/` (`SKIP_IR=1` to go on without it).
10. `make gds`: `write_stream -units 1000` is accepted and the cells in `final.gds` have their layouts.
11. `make drc`: Pegasus accepts the control file and `#DEFINE NODEN`; `drc_count.txt` matches the total in `drc/gcd.drc.sum` (else fix the count in `drc.sh`).
12. `make lvs`: passes on `MATCH` without `MISMATCH` in `lvs/gcd.lvs.rpt`; fix that check in `flow/Makefile` if Pegasus words it otherwise. Decap and tie cells are in the CDL; plain fillers are left out of `final_lvs.v`.
13. Note the gcd WNS and `runtimes.txt`; adjust the 6 ns starting period in `designs/gcd/constraint.sdc` if needed.

Back: [README.md](../README.md)
