# physical-design: optional implementation setup

No tools are required to read the charter or contribute research and design
material. Members select additional tools when their chosen work needs them.

The current Makefile is a placeholder for future implementation work. `make setup`
and `make doctor` prepare a locked, standard-library Python 3.11+ environment
with uv and describe scaffold status. Install
[uv](https://docs.astral.sh/uv/getting-started/installation/) 0.12.23 or newer
first. uv uses an available compatible interpreter or downloads one when needed;
no third-party Python packages are required.
`make test` reports `NOT IMPLEMENTED` and exits with failure because no runnable
component test exists. This describes code availability, not the value or
completeness of the team’s research, design or learning contributions.

Keep tool dependencies and ways to revisit experiments documented alongside the
work that uses them. The team can change these entry points when an implementation
or experiment calls for a different environment.

For the shared example, see the [workspace checkout guide](https://github.com/SiliconBadgers/soc/blob/main/docs/GETTING_STARTED.md).
