# Track A: open-source tools

The flow on sky130hd with Yosys, OpenROAD and KLayout. OpenROAD-flow-scripts (ORFS) run on the same netlist is the reference (`make compare`).

Track A is the folder `tracks/a`. Run every command on this page from there; paths are relative to it.

## Setup

- Tools at the versions in `tools.lock`: an ORFS build gives OpenROAD, Yosys (with `read_slang`) and KLayout ([OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) documents the build); add Verilator, Icarus Verilog and `pip install cocotb==2.1.0`.
- Clone the PDK repo next to this repo under that folder name (`git clone https://github.com/ihagedo/silicon-badgers-sky130-pdk.git silicon-badgers-sky130-pdk`), or set `SB_PDK`. This track uses its `open/sky130hd` folder.
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
| `lec` | eqy | `lec_synth.log` (RTL vs `netlist.v`), `lec_route.log` (`netlist.v` vs routed `final.v`) |
| `gls` | cocotb, Icarus | `gls_results.xml`: the RTL testbench on `final.v` with the cell models |
| `abstract` | OpenROAD | `abstract/<top>.{lef,lib,gds,cdl,v}`: the design as a macro |
| `all` | | every stage above |
| `compare` | ORFS | both flows' metrics per stage; ORFS run in `orfs/` |
| `lec-mutation` | eqy | both LEC steps must fail on broken netlists |

## Layout

| Path | |
|---|---|
| `flow/Makefile` | stages and their inputs |
| `flow/platforms/sky130hd.mk` | platform files from the PDK repo |
| `flow/scripts/pnr/` | one OpenROAD script per stage, `gds.py` |
| `flow/scripts/lec/`, `flow/scripts/gls/` | eqy configs, mutation check; gate-level simulation |
| `designs/<name>/` | `design.mk`, `constraint.sdc`, `lint_waivers.vlt` (this track); `rtl/`, `tb/` are shared, in `designs/<name>/` at the repo root (`../../designs/<name>/`) |

## Macros

- A design lists the designs it uses as hard macros in `design.mk`: `MACROS := sb_sram_256x8`.
- Every stage from `synth` on first runs `make abstract` for each macro (variant `MACRO_VARIANT`, default `base`) in its own make, so knobs on your command line do not reach the macro.
- Macro placement: `rtl_macro_placer` keeps `MACRO_CHANNEL` (default 80 um, the platform's value) between macros and to the core edge; `MACRO_HALO` (default 10 um) keeps standard cells out around each macro.
- The macro's power pins are its met4 straps; the platform power grid connects them to met5. The macro routes up to met4 only (`MAX_ROUTING_LAYER` in its `design.mk`).
- LEC treats the macro as a black box (check the macro itself with `make lec DESIGN=sb_sram_256x8`); GLS simulates its routed netlist (`abstract/<macro>.v`).
- The abstract LEF carries each pin's antenna gate and diffusion area (`abstract_antenna.py`), so antenna repair in the parent protects wires into the macro.

## Status

- gcd: every stage passes (0 DRC, LVS match); setup slack and area at or better than ORFS on the same netlist.
- tile (four `sb_sram_256x8` macros) at 65 MHz: every stage passes (0 DRC, LVS match); area and wirelength at or better than ORFS on the same netlist, setup slack +0.99 ns (ORFS +1.31 ns).
- LEC (RTL vs netlist, netlist vs routed netlist) passes on gcd, `sb_sram_256x8` and the tile; `make lec-mutation` catches 4/4 broken netlists on each. GLS on the routed netlist passes (gcd 2/2, tile 3/3 with the macros' routed netlists).
- Not yet: GLS with SDF (wire and cell) delays; today's GLS uses unit cell delays.

## Notes

- `extract_parasitics` removes the router's min-area patches from the database, so `finish.tcl` writes the layout before extracting.
- Cells added after the floorplan need `global_connect` before the outputs are written, or LVS fails on their power pins.
- Synthesis-only don't-use cells (`DONT_USE`) include clock buffers; place and route uses `PNR_DONT_USE`.
- `final.v` leaves out cells with no logic (taps, fillers, antenna diodes), as ORFS does; LVS uses `final.cdl`.
- eqy runs the Yosys installed next to it (`EQY_YOSYS`): its plugin does not load in another Yosys build.

Back: [README.md](../../../README.md)
