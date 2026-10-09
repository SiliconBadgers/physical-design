# File:        Makefile
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: SiliconBadgers RTL-to-GDS flow on sky130hd with Synopsys tools: lint, sim, synth, sta, floorplan, place, cts, grt, route, finish, gds, drc, lvs. Run `make help` for usage.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SECONDARY:

SB_ROOT  := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
FLOW     := $(SB_ROOT)/flow
SCRIPTS  := $(FLOW)/scripts
DESIGN   ?= gcd

# tools (on PATH by default)
DC_SHELL   ?= dc_shell
PT_SHELL   ?= pt_shell
ICC2_SHELL ?= icc2_shell
STARRC     ?= StarXtract
KLAYOUT    ?= klayout
# CPU cores per tool
CORES      ?= 4

# --- synthesis settings ---
DC_COMPILE    ?= compile_ultra
SYNTH_FLATTEN ?= 1
SYNTH_RETIME  ?= 0
# lint: auto (VC SpyGlass if installed), vc or vcs
LINT_TOOL     ?= auto
WAVES         ?= 0

# --- sign-off corners (ss, tt or ff): setup at ss, hold at ff ---
# tt by default, like track-a; add ss/ff for full signoff
SETUP_CORNERS ?= tt
HOLD_CORNERS  ?= tt
# corner Design Compiler optimizes for
SYNTH_CORNER  ?= $(firstword $(SETUP_CORNERS))
# GDS writer: icc2 (write_gds) or klayout (final.def merged with the cell GDS)
GDS_TOOL      ?= icc2

PLATFORM_MK := $(FLOW)/platforms/sky130hd.mk
include $(PLATFORM_MK)

DESIGN_DIR := $(SB_ROOT)/designs/$(DESIGN)
ifeq ($(wildcard $(DESIGN_DIR)/design.mk),)
  $(error DESIGN=$(DESIGN): no designs/$(DESIGN)/design.mk)
endif
include $(DESIGN_DIR)/design.mk

# --- optional design.mk settings ---
RTL_INCDIRS      ?=
RTL_DEFINES      ?=
SYNTH_DEFINES    ?=
TB_SOURCES       ?=
CORE_UTILIZATION ?= 40
ASPECT_RATIO     ?= 1
CORE_MARGIN      ?= 2
PLACE_DENSITY    ?= 0.60
# pin constraints (Tcl for IC Compiler II), sourced before place_pins
IO_CONSTRAINTS   ?=
PDN_TCL          ?= $(SCRIPTS)/icc2/pdn.tcl
GPL_TIMING_DRIVEN      ?= 1
GPL_ROUTABILITY_DRIVEN ?= 1
SKIP_CTS_REPAIR_TIMING ?= 0

ifneq ($(filter-out $(CORNERS),$(SETUP_CORNERS) $(HOLD_CORNERS) $(SYNTH_CORNER)),)
  $(error corners must be among: $(CORNERS))
endif
# corners PrimeTime runs: every setup and hold corner
STA_CORNERS := $(sort $(SETUP_CORNERS) $(HOLD_CORNERS))

# run name; each variant keeps its own build directory
VARIANT ?= base
BUILD   ?= $(SB_ROOT)/build/$(DESIGN)/$(VARIANT)
TIMES   := $(BUILD)/runtimes.txt
TIMED   := $(SCRIPTS)/util/timed.sh $(TIMES)
CLOCK_PERIOD_NS := $(shell awk '$$1 == "set" && $$2 == "clk_period" { print $$3; exit }' $(SDC_FILE) 2>/dev/null)

FLOW_DEPS := $(PLATFORM_MK) $(DESIGN_DIR)/design.mk
RUN_DEPS  := $(SCRIPTS)/util/run.tcl $(SCRIPTS)/util/metrics.tcl

# $(call snps,<stage>,<shell>,<script>,<env file>): run a Tcl script in a Synopsys shell from the build directory;
# the stage passed when run.tcl wrote <stage>.done
snps = cd $(BUILD) && rm -f $(1).done && source $(4) && \
  SB_SCRIPT=$(3) SB_STAGE=$(1) $(TIMED) $(1) $(2) -f $(SCRIPTS)/util/run.tcl < /dev/null > $(1).log 2>&1 || true; \
  grep '^SB:' $(BUILD)/$(1).log || true; \
  test -f $(BUILD)/$(1).done || { grep -m5 '^Error' $(BUILD)/$(1).log || true; \
    echo "$(1) FAILED -- read $(BUILD)/$(1).log from the first Error"; exit 1; }

# --- targets ---
.PHONY: help info all lint sim synth sta floorplan place cts grt route finish gds drc lvs clean FORCE
FORCE:
help:
	@echo "usage: make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]"
	@echo "  stages:  lint sim synth sta floorplan place cts grt route finish gds drc lvs | all | clean | info"
	@echo "  DESIGN:  $(notdir $(wildcard $(SB_ROOT)/designs/*))"
	@echo "  corners: SETUP_CORNERS=$(SETUP_CORNERS) HOLD_CORNERS=$(HOLD_CORNERS) (ss, tt or ff)"
	@echo "outputs: build/<DESIGN>/<VARIANT>/"

info:
	@echo "DESIGN=$(DESIGN) TOP=$(TOP) SDC=$(SDC_FILE) period=$(CLOCK_PERIOD_NS) ns"
	@echo "PDK=$(SB_PDK) views: $(if $(wildcard $(VIEWS)),$(VIEWS),MISSING (run $(SNPS_DIR)/make_views.sh))"
	@echo "corners: synth $(SYNTH_CORNER), setup $(SETUP_CORNERS), hold $(HOLD_CORNERS)"
	@echo "BUILD=$(BUILD)"

print-%:
	@echo '$($*)'

all: lint sim synth sta floorplan place cts grt route finish gds drc lvs

lint:      $(BUILD)/lint.log
sim:       $(BUILD)/results.xml
synth:     $(BUILD)/synth.done
sta:       $(foreach c,$(STA_CORNERS),$(BUILD)/sta_$(c).done)
floorplan: $(BUILD)/floorplan.done
place:     $(BUILD)/place.done
cts:       $(BUILD)/cts.done
grt:       $(BUILD)/grt.done
route:     $(BUILD)/route.done
finish:    $(BUILD)/signoff.done
gds:       $(BUILD)/final.gds
drc:       $(BUILD)/drc_count.txt
lvs:       $(BUILD)/lvs.done

clean:
	rm -rf $(BUILD)

$(BUILD):
	mkdir -p $@

# --- library views: built once on a licensed machine ---
$(CELL_DBS) $(CELL_NDM) $(TLUPLUS) $(NXTGRD):
	@echo "missing $@"
	@echo "build the Synopsys views once: $(SNPS_DIR)/make_views.sh (see track/README.md)"
	@exit 1

# --- lint (VC SpyGlass, or vcs +lint=all) ---
$(BUILD)/lint.log: $(RTL_FILES) $(FLOW_DEPS) $(SCRIPTS)/lint/run_lint.sh $(SCRIPTS)/lint/vc_lint.tcl | $(BUILD)
	cd $(BUILD) && TOP='$(TOP)' RTL_FILES='$(RTL_FILES)' RTL_INCDIRS='$(RTL_INCDIRS)' \
	  RTL_DEFINES='$(RTL_DEFINES)' LINT_TOOL='$(LINT_TOOL)' \
	  $(TIMED) lint bash $(SCRIPTS)/lint/run_lint.sh > lint_run.log 2>&1 || \
	  { tail -20 lint_run.log; echo "lint FAILED -- read $(BUILD)/lint_run.log"; exit 1; }
	@cp $(BUILD)/lint_run.log $@
	@grep '^SB:' $@ || true

# --- sim (cocotb on the RTL, VCS) ---
$(BUILD)/results.xml: $(RTL_FILES) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) $(FLOW_DEPS) $(SCRIPTS)/sim/run_cocotb.py | $(BUILD)
	$(TIMED) sim python3 $(SCRIPTS)/sim/run_cocotb.py --toplevel $(TOP) --test-module $(TB_MODULE) --test-dir $(TB_DIR) \
	  --build-dir $(BUILD)/sim_rtl --results $@ --waves $(WAVES) \
	  $(addprefix --incdir ,$(RTL_INCDIRS)) $(addprefix --define ,$(RTL_DEFINES)) \
	  --sources $(RTL_FILES) $(TB_SOURCES) 2>&1 | tee $(BUILD)/sim.log

# --- synth (Design Compiler) ---
# inputs for synth.tcl; the file is replaced only when its content changes
$(BUILD)/synth.env: FORCE | $(BUILD)
	@{ \
	  echo "# Inputs for flow/scripts/dc/synth.tcl (generated by make)"; \
	  echo "export SCRIPTS='$(SCRIPTS)' OUT_DIR='$(BUILD)'"; \
	  echo "export TOP='$(TOP)'"; \
	  echo "export RTL_FILES='$(RTL_FILES)'"; \
	  echo "export RTL_INCDIRS='$(RTL_INCDIRS)'"; \
	  echo "export RTL_DEFINES='$(strip $(RTL_DEFINES) $(SYNTH_DEFINES))'"; \
	  echo "export SDC_FILE='$(SDC_FILE)'"; \
	  echo "export CELL_DB='$(call cell_db,$(SYNTH_CORNER))'"; \
	  echo "export DONT_USE='$(DONT_USE)'"; \
	  echo "export DC_COMPILE='$(DC_COMPILE)' SYNTH_FLATTEN='$(SYNTH_FLATTEN)' SYNTH_RETIME='$(SYNTH_RETIME)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

$(BUILD)/synth.done: $(BUILD)/synth.env $(RTL_FILES) $(SDC_FILE) $(call cell_db,$(SYNTH_CORNER)) $(FLOW_DEPS) \
                     $(SCRIPTS)/dc/synth.tcl $(RUN_DEPS)
	@$(call snps,synth,$(DC_SHELL),$(SCRIPTS)/dc/synth.tcl,synth.env)

# --- sta (PrimeTime, pre-layout, one run per corner) and sign-off (routed, with StarRC parasitics) ---
# $(call sta_env,<corner>,<netlist>,<spef>): inputs for pt/sta.tcl
define sta_env
	@{ \
	  echo "# Inputs for flow/scripts/pt/sta.tcl (generated by make)"; \
	  echo "export SCRIPTS='$(SCRIPTS)' OUT_DIR='$(BUILD)'"; \
	  echo "export TOP='$(TOP)' CORNER='$(1)'"; \
	  echo "export NETLIST='$(2)' SPEF='$(3)'"; \
	  echo "export SDC_FILE='$(SDC_FILE)'"; \
	  echo "export CELL_DB='$(call cell_db,$(1))'"; \
	  echo "export SETUP_CORNERS='$(SETUP_CORNERS)' HOLD_CORNERS='$(HOLD_CORNERS)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@
endef

$(BUILD)/sta_%.env: FORCE | $(BUILD)
	$(call sta_env,$*,$(BUILD)/netlist.v,)
$(BUILD)/sta_%.done: $(BUILD)/sta_%.env $(BUILD)/synth.done $(SDC_FILE) $(CELL_DBS) $(SCRIPTS)/pt/sta.tcl $(RUN_DEPS)
	@$(call snps,sta_$*,$(PT_SHELL),$(SCRIPTS)/pt/sta.tcl,sta_$*.env)

# --- place and route (IC Compiler II, one run per stage; checkpoints in icc2/<stage>/) ---
$(BUILD)/pnr.env: FORCE | $(BUILD)
	@{ \
	  echo "# Inputs for flow/scripts/icc2/*.tcl and starrc/run_starrc.sh (generated by make)"; \
	  echo "export SCRIPTS='$(SCRIPTS)' OUT_DIR='$(BUILD)' CORES='$(CORES)'"; \
	  echo "export TOP='$(TOP)' NETLIST='$(BUILD)/netlist.v' SDC_FILE='$(SDC_FILE)'"; \
	  echo "export TECH_FILE='$(TECH_FILE)' CELL_NDM='$(CELL_NDM)' TLUPLUS='$(TLUPLUS)'"; \
	  echo "export CORNERS='$(CORNERS)' SETUP_CORNERS='$(SETUP_CORNERS)' HOLD_CORNERS='$(HOLD_CORNERS)'"; \
	  $(foreach c,$(CORNERS),echo "export VOLT_$(c)='$(VOLT_$(c))' TEMP_$(c)='$(TEMP_$(c))'";) \
	  echo "export SITE='$(SITE)' TAP_CELL='$(TAP_CELL)' FILL_CELLS='$(FILL_CELLS)' DIODE_CELL='$(DIODE_CELL)'"; \
	  echo "export PNR_DONT_USE='$(PNR_DONT_USE)' CTS_BUF_LIST='$(CTS_BUF_LIST)'"; \
	  echo "export IO_H_LAYER='$(IO_H_LAYER)' IO_V_LAYER='$(IO_V_LAYER)'"; \
	  echo "export MIN_ROUTING_LAYER='$(MIN_ROUTING_LAYER)' MAX_ROUTING_LAYER='$(MAX_ROUTING_LAYER)'"; \
	  echo "export MIN_CLK_ROUTING_LAYER='$(MIN_CLK_ROUTING_LAYER)'"; \
	  echo "export PDN_TCL='$(PDN_TCL)' IO_CONSTRAINTS='$(IO_CONSTRAINTS)'"; \
	  echo "export CORE_UTILIZATION='$(CORE_UTILIZATION)' ASPECT_RATIO='$(ASPECT_RATIO)' CORE_MARGIN='$(CORE_MARGIN)'"; \
	  echo "export PLACE_DENSITY='$(PLACE_DENSITY)'"; \
	  echo "export GPL_TIMING_DRIVEN='$(GPL_TIMING_DRIVEN)' GPL_ROUTABILITY_DRIVEN='$(GPL_ROUTABILITY_DRIVEN)'"; \
	  echo "export SKIP_CTS_REPAIR_TIMING='$(SKIP_CTS_REPAIR_TIMING)'"; \
	  echo "export GDS_MAP='$(GDS_MAP)' CELL_GDS='$(CELL_GDS)'"; \
	  echo "export STARRC='$(STARRC)' TECH_LEF='$(TECH_LEF)' CELL_LEF='$(CELL_LEF)' NXTGRD='$(NXTGRD)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

PNR_DEPS := $(BUILD)/pnr.env $(SDC_FILE) $(FLOW_DEPS) $(SCRIPTS)/icc2/common.tcl $(RUN_DEPS)
pnr_stage = $(call snps,$(1),$(ICC2_SHELL),$(SCRIPTS)/icc2/$(1).tcl,pnr.env)

$(BUILD)/floorplan.done: $(BUILD)/synth.done $(PNR_DEPS) $(SCRIPTS)/icc2/floorplan.tcl $(SCRIPTS)/icc2/power.upf \
                         $(PDN_TCL) $(IO_CONSTRAINTS) $(TLUPLUS) | $(CELL_NDM)
	@$(call pnr_stage,floorplan)
$(BUILD)/place.done: $(BUILD)/floorplan.done $(PNR_DEPS) $(SCRIPTS)/icc2/place.tcl
	@$(call pnr_stage,place)
$(BUILD)/cts.done: $(BUILD)/place.done $(PNR_DEPS) $(SCRIPTS)/icc2/cts.tcl
	@$(call pnr_stage,cts)
$(BUILD)/grt.done: $(BUILD)/cts.done $(PNR_DEPS) $(SCRIPTS)/icc2/grt.tcl
	@$(call pnr_stage,grt)
$(BUILD)/route.done: $(BUILD)/grt.done $(PNR_DEPS) $(SCRIPTS)/icc2/route.tcl $(SCRIPTS)/icc2/antenna.tcl
	@$(call pnr_stage,route)
$(BUILD)/finish.done: $(BUILD)/route.done $(PNR_DEPS) $(SCRIPTS)/icc2/finish.tcl
	@$(call pnr_stage,finish)

# --- finish, part 2: StarRC extraction, PrimeTime sign-off, sign-off slack into finish.json ---
$(BUILD)/final.spef: $(BUILD)/finish.done $(BUILD)/pnr.env $(SCRIPTS)/starrc/run_starrc.sh \
                     $(SCRIPTS)/starrc/starrc.cmd.in $(NXTGRD)
	cd $(BUILD) && source pnr.env && $(TIMED) extract bash $(SCRIPTS)/starrc/run_starrc.sh > extract.log 2>&1 || \
	  { tail -5 $(BUILD)/extract.log; echo "extract FAILED -- read $(BUILD)/extract.log"; exit 1; }
	@grep '^SB:' $(BUILD)/extract.log || true

$(BUILD)/signoff_%.env: FORCE | $(BUILD)
	$(call sta_env,$*,$(BUILD)/final.v,$(BUILD)/final.spef)
$(BUILD)/signoff_%.done: $(BUILD)/signoff_%.env $(BUILD)/final.spef $(SDC_FILE) $(CELL_DBS) $(SCRIPTS)/pt/sta.tcl $(RUN_DEPS)
	@$(call snps,signoff_$*,$(PT_SHELL),$(SCRIPTS)/pt/sta.tcl,signoff_$*.env)

$(BUILD)/signoff.done: $(foreach c,$(STA_CORNERS),$(BUILD)/signoff_$(c).done) $(SCRIPTS)/util/signoff_metrics.py
	python3 $(SCRIPTS)/util/signoff_metrics.py $(BUILD)/finish.json \
	  --setup $(foreach c,$(SETUP_CORNERS),$(BUILD)/signoff_$(c).json) \
	  --hold $(foreach c,$(HOLD_CORNERS),$(BUILD)/signoff_$(c).json)
	@touch $@

# --- layout: GDS (after finish), KLayout DRC and LVS ---
$(BUILD)/gds.env: FORCE | $(BUILD)
	@echo "export GDS_TOOL='$(GDS_TOOL)'" > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

ifeq ($(GDS_TOOL),klayout)
$(BUILD)/final.gds: $(BUILD)/signoff.done $(BUILD)/gds.env $(SCRIPTS)/klayout/gds.py
	cd $(BUILD) && $(TIMED) gds $(KLAYOUT) -zz -rd in_def=final.def -rd lefs="$(TECH_LEF) $(CELL_LEF)" \
	  -rd gds_in="$(CELL_GDS)" -rd lyt=$(KLAYOUT_LYT) -rd top=$(TOP) -rd out=final.gds \
	  -r $(SCRIPTS)/klayout/gds.py > gds.log 2>&1 || { tail -5 gds.log; exit 1; }
else ifeq ($(GDS_TOOL),icc2)
$(BUILD)/final.gds: $(BUILD)/signoff.done $(BUILD)/gds.env $(PNR_DEPS) $(SCRIPTS)/icc2/gds.tcl
	@$(call pnr_stage,gds)
else
  $(error GDS_TOOL=$(GDS_TOOL): use icc2 or klayout)
endif

$(BUILD)/drc_count.txt: $(BUILD)/final.gds $(SCRIPTS)/klayout/drc.sh
	cd $(BUILD) && KLAYOUT=$(KLAYOUT) $(TIMED) drc bash $(SCRIPTS)/klayout/drc.sh final.gds drc.lyrdb $(DRC_DECK) > drc.log 2>&1 || \
	  { tail -5 $(BUILD)/drc.log; echo "drc FAILED -- read $(BUILD)/drc.log"; exit 1; }
	@grep -c '<value>' $(BUILD)/drc.lyrdb > $@ || true
	@echo "KLayout DRC violations: $$(cat $@)"

$(BUILD)/lvs.done: $(BUILD)/final.gds $(CDL_FILE) $(SCRIPTS)/klayout/lvs.sh $(SCRIPTS)/klayout/v2cdl.py
	cd $(BUILD) && rm -f lvs.done && KLAYOUT=$(KLAYOUT) $(TIMED) lvs bash $(SCRIPTS)/klayout/lvs.sh \
	  $(TOP) final_lvs.v final.gds $(CDL_FILE) $(LVS_DECK) > lvs_run.log 2>&1 || \
	  { tail -5 $(BUILD)/lvs_run.log; echo "LVS FAILED -- read $(BUILD)/lvs.log"; exit 1; }
	@grep '^SB:' $(BUILD)/lvs_run.log || true
	@touch $@
