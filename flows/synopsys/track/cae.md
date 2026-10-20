# Track B2 on the UW CAE Linux machines

The CAE machines have the Synopsys tools, but they run only inside a container (AlmaLinux 8) that `synopsys-run` starts. A few things the flow needs are missing there or need a fix. [`tools/cae/setup.sh`](../tools/cae/setup.sh) installs them into one folder of yours:

| On CAE | What the script does |
|---|---|
| no KLayout (`drc`, `lvs`, the GDS steps) | installs KLayout 0.30.12 (the RHEL 8 build) and the 16 AlmaLinux 8 libraries it needs that the container lacks |
| no Python inside the container (`sim`, `gls`, `finish`), and a venv made from the machine's Python does not run there | installs Python 3.10.22 from conda-forge with cocotb 2.1.0 |
| StarRC 2026.03 stops with `GLIBCXX_3.4.32' not found` (`finish`, `make_views.sh`) | writes `StarXtract` and `grdgenxo` wrappers that load the `libstdc++` StarRC ships for itself |

It also writes `env.sh`, which puts all of this first on `PATH`. Everything else on this page is CAE's own commands; then follow [README.md](README.md).

## Disk and machines

- Your home folder is small. One run of every design takes about 0.5 GB, the tools 0.5 GB, the PDK with its views 0.2 GB.
- `/var/tmp` is the local disk of one machine: large, but the other machines do not see it, and it is not backed up.
- So pick one machine and log in to it by name every time. A pool name that picks a free machine for you lands on one whose `/var/tmp` does not have your files. Keep your own changes in git.

## Once per machine

On the machine, not inside the container (it has no git):

```
mkdir -p /var/tmp/$USER/sb && cd /var/tmp/$USER/sb
git clone <PDK repo URL> silicon-badgers-sky130-pdk
git clone <pd-flow repo URL> pd-flow
pd-flow/tracks/b2/tools/cae/setup.sh
```

- The script installs into `/var/tmp/$USER/sb-tools`; `--prefix <folder>` picks another new or empty folder (under `/var/tmp` or your home, which the container sees). It takes a minute or two.
- It ends by starting each tool inside the container: `python 3.10.22 cocotb 2.1.0`, `KLayout 0.30.12` and, if the modules are loaded, `StarXtract Version: Y-2026.03`.
- Running it again skips what is installed and rewrites the wrappers. If you move the folder, run it again.

## Every session

```
module load synopsys/suite/2026 synopsys/starrc/2026.03
source /var/tmp/$USER/sb-tools/env.sh
synopsys-run
```

- `synopsys-run` without arguments opens a shell inside the container (prompt `synopsys>`); `exit` leaves it. With arguments it runs one command there, for example `synopsys-run make all DESIGN=gcd`.
- Source `env.sh` after the module loads: the suite brings a `python3` of its own. `env.sh` warns if the modules are not loaded.
- `module load` prints "Run synopsys-run to enter the container" and Lmod warnings about StarRC with Milkyway or Saber; this flow uses neither.
- The tile takes about half an hour: start the session inside `tmux` (outside the container) so a lost connection does not stop the run.

## Synopsys views

Build them once per PDK checkout, in the session above (about 30 minutes):

```
cd /var/tmp/$USER/sb/silicon-badgers-sky130-pdk/synopsys && ./make_views.sh
```

Or use views someone has already built, for example a mentor's copy: `export SB_VIEWS=<their views folder>` before `synopsys-run`, or `make <stage> SB_VIEWS=<folder>`. `make info` shows the views the flow uses.

## Then

```
cd /var/tmp/$USER/sb/pd-flow/tracks/b2
make info DESIGN=gcd
make all DESIGN=gcd
```

and on through [README.md](README.md): Run, then the First run checklist. On CAE (2026-10-13) `make all` took about 5 minutes for gcd, 10 for `sb_sram_256x8` (`make abstract`) and 23 for the tile after its macro (KLayout LVS alone 10).

## Messages

| Message | Cause |
|---|---|
| `version 'GLIBCXX_3.4.32' not found` from `StarXtract` or `grdgenxo`; `python3: command not found` or `No module named 'cocotb'` | `env.sh` not sourced, or sourced before the module loads: source it again |
| `WARNING: StarXtract was invoked without loading the appropriate modules first!` | the modules are not loaded |
| `klayout: error while loading shared libraries` | KLayout runs only inside the container |
| `vcs1fe: error while loading shared libraries: libelf.so.1` | `vcs` without `-full64` starts a 32-bit front end, which the container cannot run (and still exits 0). The flow always passes `-full64` |

Tested on CAE on 2026-10-19 with the container image of 2026-09-18 (`/srv/auto/containers/cae-alma8-base_latest.sif`).

Back: [README.md](README.md)
