.PHONY: setup doctor test synth-unit synth-units ppa-table
UV ?= uv
PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PYTHON ?= python3
RUN_PYTHON = $(UV) run --locked --project "$(PROJECT_ROOT)" $(PYTHON)
setup:
	$(UV) sync --locked --project "$(PROJECT_ROOT)"
	$(RUN_PYTHON) -c "import sys; assert sys.version_info >= (3, 11), 'Python 3.11+ required'; print('PASS setup')"
doctor: setup
	@echo "Scaffold only: see README for implementation prerequisites."
test:
	@echo "NOT IMPLEMENTED: this repository is a scaffold; no component test exists yet."
	@exit 2

# PPA flow (flows/ppa): Design Compiler synthesis through FuseSoC; options as in flows/ppa (UNIT, EFFORT, CORNER, CLOCK_NS, TOOL_WRAP)
synth-unit:
	$(MAKE) -C flows/ppa synth
synth-units:
	$(MAKE) -C flows/ppa units
ppa-table:
	$(MAKE) -C flows/ppa table
