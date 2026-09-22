# Physical Design starting material

September 22, 2026. Initial investigations for team discussion; no personal assignments or deadlines.

## Shared starting points

- [Editable architecture diagram](https://github.com/SiliconBadgers/architecture/blob/main/docs/accelerator-diagram.md) and [candidate boundaries](https://github.com/SiliconBadgers/architecture/blob/main/contracts/accelerator-boundaries.md).
- [Workload cases and source shapes](https://github.com/SiliconBadgers/architecture/blob/main/docs/workload-cases.md).
- [Measured llama.cpp report](https://github.com/SiliconBadgers/software/blob/main/experiments/llama-cpp/2026-09-22/REPORT.md) and [reproduction procedure](https://github.com/SiliconBadgers/software/blob/main/experiments/llama-cpp/2026-09-22/README.md).
- [Parallel team investigations](https://github.com/SiliconBadgers/planning/blob/main/docs/team-start.md).

The diagram and engine split are proposals. Start from available shapes and
reference cases now; use explicit parameters or stubs where decisions remain
open. Software's broader profiling study is not a prerequisite. Preserve the
source revision, assumptions, commands and limits of each result. Members and
leads can choose a different investigation that resolves a relevant uncertainty.


## First useful output

A feasibility comparison that gives Compute and Memory usable constraints before
full accelerator RTL exists. Identify accessible tools, process/library versions,
SRAM macros and usable views. Do not invent a process node, clock or area budget.

## Procedure

1. Inventory the actual standard-cell and memory resources: capacity, width/depth, ports, latency, timing corners and available models/views. Record access limitations.
2. Select small representative arithmetic and storage probes with Compute and Memory. Parameterize width, lane count, pipelining and bank count.
3. Where tools/libraries are available, synthesize the probes with reproducible constraints and record area, timing, inferred/mapped memories and warnings.
4. Compare shared versus replicated arithmetic and the connectivity cost of candidate buffers. Explain fanout, long buses and simultaneous memory access implications.
5. Publish ranges or unresolved constraints when target data is missing. Keep FPGA utilization, generic synthesis estimates and ASIC mapped results distinct.

## Ready for a joint review when

Each estimate names its tool/version, target/library, corner, constraints, source
revision and whether memories/interconnect are included. Report synthesis results
as synthesis results, not achieved post-layout frequency/power. A useful first
result can eliminate an infeasible width/port configuration without a complete
chip netlist. Save the probe and run procedure in `experiments/<study>/`.

`make test` currently reports an unimplemented scaffold. Tool installation alone
is not the engineering deliverable; characterize a relevant constraint or state
precisely which missing input prevents that characterization.
