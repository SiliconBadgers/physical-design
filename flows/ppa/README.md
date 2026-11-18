# PPA flow

Design Compiler synthesis of a unit at the sky130hd library, with one table of its power, performance and area. FuseSoC keeps the list of units: each unit is a `.core` file next to its RTL under `flows/designs/`, with the RTL files, the top module and the constraint file. The make targets call FuseSoC, so a unit is added by writing its core, not by editing the flow.

## Setup

1. From the repo root, `make setup` installs FuseSoC (uv 0.12.23 or newer).
2. Clone the PDK into the repo root and build its Synopsys views, as on the [Track B2 setup page](../synopsys/track/cae.md). Only the `.db` files are used here.
3. Design Compiler must be on `PATH` (`dc_shell-t`). On UW CAE, run `module load synopsys/suite` and add `TOOL_WRAP=synopsys-run` to the make line.

## Run

From `flows/ppa`:

```
make synth UNIT=gcd                 # one unit, medium effort, tt corner
make synth UNIT=gcd EFFORT=high CLOCK_NS=4
make units EFFORT=low               # every unit, then the table
make table                          # the table of every run so far
```

From the repo root, `make synth-unit`, `make synth-units` and `make ppa-table` do the same and take the same options.

| Option | Values | Default |
|---|---|---|
| `UNIT` | a core under `flows/designs/` (`make help` lists them) | `gcd` |
| `EFFORT` | `low`: `compile`; `medium`: `compile_ultra`; `high`: `compile_ultra`, then an incremental `compile_ultra` | `medium` |
| `CORNER` | `ss`, `tt`, `ff` | `tt` |
| `CLOCK_NS` | clock period in ns | the period in the unit's constraint file |

## Results

Each run goes to `build/<unit>/<effort>-<corner>[-<clock>ns]/`: `work/reports/` has the Design Compiler reports and `ppa.json` has the numbers. `make table` writes every run to `build/ppa.md` and `build/ppa.csv`:

| Column | From |
|---|---|
| Clock (ns) | the clock period |
| Slack (ns) | worst setup slack; negative means the clock isn't met |
| Fmax (MHz) | 1000 / (clock − slack) |
| Area (um2) | total cell area |
| Cells | leaf cells |
| Power (mW) | internal + switching + leakage, with Design Compiler's default activity (not from simulation) |
| Status | `met`, `timing not met`, `latches`, `unconstrained` or `failed` |

The CSV also has the TNS, combinational, sequential and macro area, each power part and the git revision. These are post-synthesis estimates, not results after place and route.

## Add a unit

Write `flows/designs/<unit>/<unit>.core` like [gcd.core](../designs/gcd/gcd.core): an `rtl` fileset, a `constraints` fileset with the unit's SDC copied to `synth.sdc`, and a `synth` target that depends on `::ppa_dc`. The SDC sets `clk_period` only if it isn't set yet, so `CLOCK_NS` can change it.
