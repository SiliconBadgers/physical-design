# File:        Makefile
# Author:      Isaac Hagedorn
# Date:        2026-11-17
# Description: PPA flow: Design Compiler synthesis of one unit or every unit at the sky130hd library, through FuseSoC,
#              and one table of the results. Run from flows/ppa (make help); README.md has the details.

SB_ROOT := $(abspath ..)
ROOT    := $(abspath ../..)
include $(SB_ROOT)/synopsys/flow/platforms/sky130hd.mk

# --- options ---
UNIT      ?= gcd
# low | medium | high
EFFORT    ?= medium
# ss | tt | ff
CORNER    ?= tt
# clock period in ns; empty = the period in the unit's constraint file
CLOCK_NS  ?=
# command that runs Design Compiler's make, for example synopsys-run on UW CAE; empty = dc_shell-t on PATH
TOOL_WRAP ?=
UV        ?= uv
FUSESOC   ?= $(UV) run --locked --project $(ROOT) fusesoc
PYTHON    ?= $(UV) run --locked --project $(ROOT) python3

# every core under flows/designs is a unit
DESIGNS := $(SB_ROOT)/designs
UNITS   := $(sort $(notdir $(patsubst %/,%,$(dir $(wildcard $(DESIGNS)/*/*.core)))))
BUILD   := build
RUN      = $(BUILD)/$(UNIT)/$(EFFORT)-$(CORNER)$(if $(CLOCK_NS),-$(CLOCK_NS)ns)

.PHONY: help synth units table

help:
	@echo "make synth UNIT=<unit> [EFFORT=low|medium|high] [CORNER=ss|tt|ff] [CLOCK_NS=<ns>] [TOOL_WRAP=synopsys-run]"
	@echo "make units [EFFORT=...]   synthesize every unit, then print the table"
	@echo "make table                print the table of every run in $(BUILD)/"
	@echo "units: $(UNITS)"

# FuseSoC writes the run folder (file list, project script, Makefile), the Makefile runs Design Compiler,
# ppa.py reads the reports; it also records a run that stopped early, so the table shows it as failed
synth:
	@test -f $(call cell_db,$(CORNER)) || { echo "no cell library $(call cell_db,$(CORNER)): build the PDK views (flows/synopsys/track/cae.md)"; exit 1; }
	rm -rf $(RUN)
	-$(FUSESOC) --cores-root $(DESIGNS) --cores-root dc run --setup --build-root $(abspath $(RUN)) \
	  --work-root $(abspath $(RUN))/work --target synth ::$(UNIT) && \
	printf '%s\n' 'set effort $(EFFORT)' 'set cell_db $(call cell_db,$(CORNER))' 'set dont_use {$(DONT_USE)}' \
	  $(if $(CLOCK_NS),'set clk_period $(CLOCK_NS)') > $(RUN)/work/settings.tcl && \
	{ echo "Design Compiler: $(UNIT), effort $(EFFORT), $(CORNER) (log: $(RUN)/work/reports/synth.log)"; \
	  $(TOOL_WRAP) $(MAKE) -C $(abspath $(RUN))/work < /dev/null > $(RUN)/work/make.log 2>&1; }
	$(PYTHON) ppa.py run $(RUN) $(UNIT) $(EFFORT) $(CORNER)

units:
	@fail=0; for u in $(UNITS); do $(MAKE) --no-print-directory synth UNIT=$$u || fail=1; done; \
	$(MAKE) --no-print-directory table; exit $$fail

table:
	@$(PYTHON) ppa.py table $(BUILD)
