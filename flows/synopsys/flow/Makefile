# File:        Makefile
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: SiliconBadgers RTL-to-GDS flow on sky130hd with Synopsys tools: lint, sim, synth, sta, floorplan, place, cts, grt, route, finish, gds, drc, lvs, lec, gls, abstract. Run `make help` for usage.

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
FM_SHELL   ?= fm_shell
# Library Compiler and IC Compiler II Library Manager (macro abstracts)
LC_SHELL      ?= lc_shell
ICC2_LM_SHELL ?= icc2_lm_shell
# CPU cores per tool
CORES      ?= 4

# --- synthesis settings ---
DC_COMPILE    ?= compile_ultra
SYNTH_FLATTEN ?= 1
SYNTH_RETIME  ?= 0
# lint: auto (VC SpyGlass if installed), vc or vcs
LINT_TOOL     ?= auto
WAVES         ?= 0
# wall-clock limit of one sim or gls run in seconds; a normal run takes well under a minute
SIM_TIMEOUT ?= 900
# extra VCS compile options for gate-level simulation
GLS_VCS_ARGS  ?=

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
# ns of setup clock uncertainty IC Compiler II adds to the SDC's, in every scenario (place and route only: Design Compiler
# and PrimeTime read the SDC as it is). IC Compiler II with TLU+ sees up to 0.15 ns more setup slack than sign-off.
PNR_SETUP_MARGIN ?= 0.15
# lint black boxes and simulation models of the hard macros
MACRO_VERILOG    ?=
MACRO_SIM_MODELS ?=

# hard macros: designs built first and used as abstracts (design.mk: MACROS := <design> ...)
MACROS        ?=
MACRO_VARIANT ?= base
macro_abs      = $(SB_ROOT)/build/$(1)/$(MACRO_VARIANT)/abstract/$(1)
MACRO_LEFS    := $(foreach m,$(MACROS),$(call macro_abs,$(m)).lef)
MACRO_GDS     := $(foreach m,$(MACROS),$(call macro_abs,$(m)).gds)
MACRO_CDL     := $(foreach m,$(MACROS),$(call macro_abs,$(m)).cdl)
MACRO_NDMS    := $(foreach m,$(MACROS),$(call macro_abs,$(m)).ndm)
# routed logic netlists of the macros, for gate-level simulation
MACRO_NETLISTS := $(foreach m,$(MACROS),$(call macro_abs,$(m)).v)
# $(call macro_dbs,<corner>): the macros' timing models at one corner
macro_dbs      = $(foreach m,$(MACROS),$(call macro_abs,$(m))_$(1).db)
MACRO_DBS     := $(foreach c,$(CORNERS),$(call macro_dbs,$(c)))
MACRO_FILES   := $(MACRO_LEFS) $(MACRO_GDS) $(MACRO_CDL) $(MACRO_DBS) $(MACRO_NDMS) $(MACRO_NETLISTS)
# keep-out ring for standard cells around each macro, and minimum channel between macros and the core edge (um)
MACRO_HALO    ?= 10
MACRO_CHANNEL ?= 80

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
# clock period from the SDC: `set clk_period <ns>` or `set clk_period [expr {<a> / <b>}]`
CLOCK_PERIOD_NS := $(shell awk '$$1 == "set" && $$2 == "clk_period" { v = $$3; if (v == "[expr") { a = $$4; b = $$6; \
  gsub(/[^0-9.]/, "", a); gsub(/[^0-9.]/, "", b); v = a / b }; print v; exit }' $(SDC_FILE) 2>/dev/null)

FLOW_DEPS := $(PLATFORM_MK) $(DESIGN_DIR)/design.mk
RUN_DEPS  := $(SCRIPTS)/util/run.tcl $(SCRIPTS)/util/metrics.tcl

# $(call snps,<stage>,<shell>,<script>,<env file>): run a Tcl script in a Synopsys shell from the build directory;
# the stage passed when run.tcl wrote <stage>.done and the log has no "Error:" line (check_log.sh, with its waivers):
# some commands print an Error and return normally (write_gds, create_terminal, read_sdc in Design Compiler).
# A failing stage leaves no <stage>.done; .DELETE_ON_ERROR removes the file it was making.
snps = cd $(BUILD) && rm -f $(1).done && source $(4) && \
  SB_SCRIPT=$(3) SB_STAGE=$(1) $(TIMED) $(1) $(2) -f $(SCRIPTS)/util/run.tcl < /dev/null > $(1).log 2>&1 || true; \
  grep '^SB:' $(BUILD)/$(1).log || true; \
  test -f $(BUILD)/$(1).done || { grep -m5 '^Error' $(BUILD)/$(1).log || true; \
    echo "$(1) FAILED -- read $(BUILD)/$(1).log from the first Error"; exit 1; }; \
  $(SCRIPTS)/util/check_log.sh $(BUILD)/$(1).log || { rm -f $(BUILD)/$(1).done; \
    echo "$(1) FAILED -- the tool went on after an Error: read $(BUILD)/$(1).log from the first Error"; exit 1; }

# --- targets ---
.PHONY: help info all lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls lec-mutation abstract macros clean FORCE
# stages run in order (macros are built before synthesis)
.NOTPARALLEL:
FORCE:
help:
	@echo "usage: make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]"
	@echo "  stages:  lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls | abstract | all | clean | info"
	@echo "  DESIGN:  $(notdir $(wildcard $(SB_ROOT)/designs/*))"
	@echo "  corners: SETUP_CORNERS=$(SETUP_CORNERS) HOLD_CORNERS=$(HOLD_CORNERS) (ss, tt or ff)"
	@echo "  lec-mutation: LEC must fail on broken netlists"
	@echo "outputs: build/<DESIGN>/<VARIANT>/"

info:
	@echo "DESIGN=$(DESIGN) TOP=$(TOP) SDC=$(SDC_FILE) period=$(CLOCK_PERIOD_NS) ns"
	@echo "PDK=$(SB_PDK) views: $(if $(wildcard $(VIEWS)),$(VIEWS),MISSING (run $(SNPS_DIR)/make_views.sh))"
	@echo "corners: synth $(SYNTH_CORNER), setup $(SETUP_CORNERS), hold $(HOLD_CORNERS)"
	@echo "BUILD=$(BUILD)"

print-%:
	@echo '$($*)'

all: lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls

lint:      $(BUILD)/lint.log
sim:       $(if $(TB_MODULE),$(BUILD)/results.xml)
synth:     macros $(BUILD)/synth.done
sta:       macros $(foreach c,$(STA_CORNERS),$(BUILD)/sta_$(c).done)
floorplan: macros $(BUILD)/floorplan.done
place:     macros $(BUILD)/place.done
cts:       macros $(BUILD)/cts.done
grt:       macros $(BUILD)/grt.done
route:     macros $(BUILD)/route.done
finish:    macros $(BUILD)/signoff.done
gds:       macros $(BUILD)/final.gds
drc:       macros $(BUILD)/drc_count.txt
lvs:       macros $(BUILD)/lvs.done
lec:       macros $(BUILD)/lec_synth.done $(BUILD)/lec_route.done
gls:       macros $(if $(TB_MODULE),$(BUILD)/gls_results.xml)

# build each macro's abstract in its own make, without this make's command-line settings (make also exports them
# to the environment); a dry run stays a dry run
CMDLINE_VARS = $(foreach v,$(.VARIABLES),$(if $(filter command line,$(origin $(v))),$(v)))
macros:
	@$(foreach m,$(MACROS),env -u MAKEFLAGS -u MFLAGS $(addprefix -u ,$(CMDLINE_VARS)) \
	  $(MAKE) $(if $(findstring n,$(firstword -$(MAKEFLAGS))),-n) \
	  --no-print-directory -C $(SB_ROOT) abstract DESIGN=$(m) VARIANT=$(MACRO_VARIANT) SB_PDK=$(SB_PDK) CORES=$(CORES) \
	  DC_SHELL=$(DC_SHELL) PT_SHELL=$(PT_SHELL) ICC2_SHELL=$(ICC2_SHELL) ICC2_LM_SHELL=$(ICC2_LM_SHELL) \
	  LC_SHELL=$(LC_SHELL) STARRC=$(STARRC) KLAYOUT=$(KLAYOUT) &&) true
$(MACRO_FILES): ;

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
$(BUILD)/lint.log: $(RTL_FILES) $(MACRO_VERILOG) $(FLOW_DEPS) $(SCRIPTS)/lint/run_lint.sh $(SCRIPTS)/lint/vc_lint.tcl | $(BUILD)
	cd $(BUILD) && TOP='$(TOP)' RTL_FILES='$(strip $(RTL_FILES) $(MACRO_VERILOG))' RTL_INCDIRS='$(RTL_INCDIRS)' \
	  RTL_DEFINES='$(RTL_DEFINES)' LINT_TOOL='$(LINT_TOOL)' \
	  $(TIMED) lint bash $(SCRIPTS)/lint/run_lint.sh > lint_run.log 2>&1 || \
	  { tail -20 lint_run.log; echo "lint FAILED -- read $(BUILD)/lint_run.log"; exit 1; }
	@cp $(BUILD)/lint_run.log $@
	@grep '^SB:' $@ || true

# --- sim (cocotb on the RTL, VCS) ---
$(BUILD)/results.xml: $(RTL_FILES) $(MACRO_SIM_MODELS) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) $(FLOW_DEPS) $(SCRIPTS)/sim/run_cocotb.py | $(BUILD)
	$(TIMED) sim python3 $(SCRIPTS)/sim/run_cocotb.py --timeout $(SIM_TIMEOUT) --toplevel $(TOP) --test-module $(TB_MODULE) --test-dir $(TB_DIR) \
	  --build-dir $(BUILD)/sim_rtl --results $@ --waves $(WAVES) \
	  $(addprefix --incdir ,$(RTL_INCDIRS)) $(addprefix --define ,$(RTL_DEFINES)) \
	  --sources $(RTL_FILES) $(MACRO_SIM_MODELS) $(TB_SOURCES) 2>&1 | tee $(BUILD)/sim.log

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
	  $(if $(MACROS),echo "export MACRO_DBS='$(call macro_dbs,$(SYNTH_CORNER))'";) \
	  echo "export DONT_USE='$(DONT_USE)'"; \
	  echo "export DC_COMPILE='$(DC_COMPILE)' SYNTH_FLATTEN='$(SYNTH_FLATTEN)' SYNTH_RETIME='$(SYNTH_RETIME)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

$(BUILD)/synth.done: $(BUILD)/synth.env $(RTL_FILES) $(SDC_FILE) $(call cell_db,$(SYNTH_CORNER)) $(call macro_dbs,$(SYNTH_CORNER)) $(FLOW_DEPS) \
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
	  $(if $(MACROS),echo "export MACRO_DBS='$(call macro_dbs,$(1))'";) \
	  echo "export SETUP_CORNERS='$(SETUP_CORNERS)' HOLD_CORNERS='$(HOLD_CORNERS)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@
endef

$(BUILD)/sta_%.env: FORCE | $(BUILD)
	$(call sta_env,$*,$(BUILD)/netlist.v,)
$(BUILD)/sta_%.done: $(BUILD)/sta_%.env $(BUILD)/synth.done $(SDC_FILE) $(CELL_DBS) $(MACRO_DBS) $(SCRIPTS)/pt/sta.tcl $(RUN_DEPS)
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
	  echo "export SKIP_CTS_REPAIR_TIMING='$(SKIP_CTS_REPAIR_TIMING)' PNR_SETUP_MARGIN='$(PNR_SETUP_MARGIN)'"; \
	  echo "export GDS_MAP='$(GDS_MAP)' CELL_GDS='$(CELL_GDS)'"; \
	  echo "export STARRC='$(STARRC)' TECH_LEF='$(TECH_LEF)' CELL_LEF='$(CELL_LEF)' NXTGRD='$(NXTGRD)'"; \
	  $(if $(MACROS),echo "export MACRO_NDMS='$(MACRO_NDMS)' MACRO_LEFS='$(MACRO_LEFS)' MACRO_GDS='$(MACRO_GDS)'";) \
	  $(if $(MACROS),echo "export MACRO_HALO='$(MACRO_HALO)' MACRO_CHANNEL='$(MACRO_CHANNEL)'";) \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

PNR_DEPS := $(BUILD)/pnr.env $(SDC_FILE) $(FLOW_DEPS) $(SCRIPTS)/icc2/common.tcl $(RUN_DEPS)
pnr_stage = $(call snps,$(1),$(ICC2_SHELL),$(SCRIPTS)/icc2/$(1).tcl,pnr.env)

$(BUILD)/floorplan.done: $(BUILD)/synth.done $(PNR_DEPS) $(SCRIPTS)/icc2/floorplan.tcl $(SCRIPTS)/icc2/power.upf \
                         $(PDN_TCL) $(IO_CONSTRAINTS) $(TLUPLUS) $(MACRO_LEFS) $(MACRO_DBS) $(MACRO_NDMS) \
                         $(if $(MACROS),$(SCRIPTS)/icc2/macro_place.tcl) | $(CELL_NDM)
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
	@$(SCRIPTS)/util/check_log.sh $(BUILD)/extract.log '^ERROR' || \
	  { echo "extract FAILED -- StarRC went on after an ERROR: read $(BUILD)/extract.log"; exit 1; }
	@grep '^SB:' $(BUILD)/extract.log || true

$(BUILD)/signoff_%.env: FORCE | $(BUILD)
	$(call sta_env,$*,$(BUILD)/final.v,$(BUILD)/final.spef)
$(BUILD)/signoff_%.done: $(BUILD)/signoff_%.env $(BUILD)/final.spef $(SDC_FILE) $(CELL_DBS) $(MACRO_DBS) $(SCRIPTS)/pt/sta.tcl $(RUN_DEPS)
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

# drawing metal under the top cell's pins, so a wire of a parent design that ends at a pin connects
pin_metal = cd $(BUILD) && $(TIMED) pin_metal $(KLAYOUT) -zz -rd gds=final.gds -rd top=$(TOP) \
  -r $(SCRIPTS)/klayout/pin_metal.py > pin_metal.log 2>&1 || { tail -5 pin_metal.log; exit 1; }
$(BUILD)/final.gds: $(SCRIPTS)/klayout/pin_metal.py

ifeq ($(GDS_TOOL),klayout)
$(BUILD)/final.gds: $(BUILD)/finish.done $(BUILD)/gds.env $(MACRO_LEFS) $(MACRO_GDS) $(SCRIPTS)/klayout/gds.py
	cd $(BUILD) && $(TIMED) gds $(KLAYOUT) -zz -rd in_def=final.def -rd lefs="$(strip $(TECH_LEF) $(CELL_LEF) $(MACRO_LEFS))" \
	  -rd gds_in="$(strip $(CELL_GDS) $(MACRO_GDS))" -rd lyt=$(KLAYOUT_LYT) -rd top=$(TOP) -rd out=final.gds \
	  -r $(SCRIPTS)/klayout/gds.py > gds.log 2>&1 || { tail -5 gds.log; exit 1; }
	$(pin_metal)
else ifeq ($(GDS_TOOL),icc2)
$(BUILD)/final.gds: $(BUILD)/finish.done $(BUILD)/gds.env $(PNR_DEPS) $(MACRO_GDS) $(GDS_MAP) $(SCRIPTS)/icc2/gds.tcl
	@$(call pnr_stage,gds)
	$(pin_metal)
else
  $(error GDS_TOOL=$(GDS_TOOL): use icc2 or klayout)
endif

$(BUILD)/drc_count.txt: $(BUILD)/final.gds $(SCRIPTS)/klayout/drc.sh
	cd $(BUILD) && KLAYOUT=$(KLAYOUT) $(TIMED) drc bash $(SCRIPTS)/klayout/drc.sh final.gds drc.lyrdb $(DRC_DECK) > drc.log 2>&1 || \
	  { tail -5 $(BUILD)/drc.log; echo "drc FAILED -- read $(BUILD)/drc.log"; exit 1; }
	@grep -c '<value>' $(BUILD)/drc.lyrdb > $@ || true
	@echo "KLayout DRC violations: $$(cat $@)"

$(BUILD)/lvs.done: $(BUILD)/final.gds $(CDL_FILE) $(MACRO_CDL) $(SCRIPTS)/klayout/lvs.sh $(SCRIPTS)/klayout/v2cdl.py
	cd $(BUILD) && rm -f lvs.done && KLAYOUT=$(KLAYOUT) $(TIMED) lvs bash $(SCRIPTS)/klayout/lvs.sh \
	  $(strip $(TOP) final_lvs.v final.gds $(CDL_FILE) $(LVS_DECK) $(MACRO_CDL)) > lvs_run.log 2>&1 || \
	  { tail -5 $(BUILD)/lvs_run.log; echo "LVS FAILED -- read $(BUILD)/lvs.log"; exit 1; }
	@grep '^SB:' $(BUILD)/lvs_run.log || true
	@touch $@

# --- lec (Formality): RTL vs netlist.v with synth.svf, then netlist.v vs the routed final_logic.v ---
# hard macros are black boxes (their .db has no logic); check a macro with make lec DESIGN=<macro>
LEC_IMPL_synth := $(BUILD)/netlist.v
LEC_IMPL_route := $(BUILD)/final_logic.v
$(BUILD)/lec_%.env: FORCE | $(BUILD)
	@{ \
	  echo "# Inputs for flow/scripts/fm/lec.tcl (generated by make)"; \
	  echo "export SCRIPTS='$(SCRIPTS)' OUT_DIR='$(BUILD)'"; \
	  echo "export TOP='$(TOP)' LEC_STEP='$*'"; \
	  echo "export RTL_FILES='$(RTL_FILES)'"; \
	  echo "export RTL_INCDIRS='$(RTL_INCDIRS)'"; \
	  echo "export RTL_DEFINES='$(strip $(RTL_DEFINES) $(SYNTH_DEFINES))'"; \
	  echo "export SVF='$(BUILD)/synth.svf' REF_NETLIST='$(BUILD)/netlist.v'"; \
	  echo "export IMPL_NETLIST='$(LEC_IMPL_$*)'"; \
	  echo "export CELL_DB='$(call cell_db,$(SYNTH_CORNER))'"; \
	  $(if $(MACROS),echo "export MACRO_DBS='$(call macro_dbs,$(SYNTH_CORNER))'";) \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

$(BUILD)/lec_route.done: $(BUILD)/finish.done
$(BUILD)/lec_%.done: $(BUILD)/lec_%.env $(BUILD)/synth.done $(RTL_FILES) $(call cell_db,$(SYNTH_CORNER)) \
                     $(call macro_dbs,$(SYNTH_CORNER)) $(SCRIPTS)/fm/lec.tcl $(RUN_DEPS)
	@$(call snps,lec_$*,$(FM_SHELL),$(SCRIPTS)/fm/lec.tcl,lec_$*.env)

# LEC must still fail on a broken gate netlist (two mutants for each LEC step)
lec-mutation: macros $(BUILD)/lec_synth.env $(BUILD)/lec_route.env $(BUILD)/synth.done $(BUILD)/finish.done
	python3 $(SCRIPTS)/fm/lec_mutation.py --work $(BUILD)/lec_mutation \
	  --cmd "SB_SCRIPT=$(SCRIPTS)/fm/lec.tcl $(FM_SHELL) -f $(SCRIPTS)/util/run.tcl" \
	  --check $(BUILD)/lec_synth.env $(LEC_IMPL_synth) --check $(BUILD)/lec_route.env $(LEC_IMPL_route)

# --- gls (cocotb on the routed logic netlist, VCS): cell models; hard macros as their routed netlists ---
$(BUILD)/gls_results.xml: $(BUILD)/finish.done $(CELL_VERILOG) $(MACRO_NETLISTS) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) \
                          $(FLOW_DEPS) $(SCRIPTS)/sim/run_cocotb.py | $(BUILD)
	$(TIMED) gls python3 $(SCRIPTS)/sim/run_cocotb.py --timeout $(SIM_TIMEOUT) --toplevel $(TOP) --test-module $(TB_MODULE) --test-dir $(TB_DIR) \
	  --build-dir $(BUILD)/sim_gls --results $@ --waves $(WAVES) \
	  $(foreach d,$(GLS_DEFINES),--define '$(d)') $(addprefix --vcs-arg=,$(GLS_VCS_ARGS)) \
	  --sources $(BUILD)/final_logic.v $(CELL_VERILOG) $(MACRO_NETLISTS) $(TB_SOURCES) 2>&1 | tee $(BUILD)/gls.log

# --- abstract: this design as a hard macro of another design ---
# LEF (IC Compiler II frame), timing model per corner (PrimeTime, compiled by Library Compiler; <top>.lib is tt),
# GDS, CDL, logic netlist (GLS), and the IC Compiler II reference library built from the LEF and the models
ABS       := $(BUILD)/abstract
ABS_FILES := $(ABS)/$(TOP).lef $(ABS)/$(TOP).lib $(ABS)/$(TOP).gds $(ABS)/$(TOP).cdl $(ABS)/$(TOP).v $(BUILD)/abstract_ndm.done
abstract: macros $(ABS_FILES)

$(ABS):
	mkdir -p $@

$(ABS)/$(TOP).lef: $(BUILD)/finish.done $(PNR_DEPS) $(SCRIPTS)/icc2/abstract.tcl | $(ABS)
	@$(call pnr_stage,abstract)

$(BUILD)/model_%.env: FORCE | $(BUILD)
	$(call sta_env,$*,$(BUILD)/final.v,$(BUILD)/final.spef)
$(ABS)/$(TOP)_%.lib: $(BUILD)/model_%.env $(BUILD)/final.spef $(SDC_FILE) $(CELL_DBS) $(MACRO_DBS) $(SCRIPTS)/pt/model.tcl $(RUN_DEPS) | $(ABS)
	@$(call snps,model_$*,$(PT_SHELL),$(SCRIPTS)/pt/model.tcl,model_$*.env)
$(ABS)/$(TOP)_%.db: $(ABS)/$(TOP)_%.lib $(SCRIPTS)/lc/lib2db.tcl $(RUN_DEPS)
	@$(call snps,lib2db_$*,$(LC_SHELL),$(SCRIPTS)/lc/lib2db.tcl,model_$*.env)
$(ABS)/$(TOP).lib: $(ABS)/$(TOP)_tt.lib
	cp $< $@

$(BUILD)/abstract_ndm.done: $(ABS)/$(TOP).lef $(foreach c,$(CORNERS),$(ABS)/$(TOP)_$(c).db) $(BUILD)/pnr.env \
                            $(SCRIPTS)/icc2/abstract_ndm.tcl $(RUN_DEPS)
	@$(call snps,abstract_ndm,$(ICC2_LM_SHELL),$(SCRIPTS)/icc2/abstract_ndm.tcl,pnr.env)

$(ABS)/$(TOP).gds: $(BUILD)/final.gds $(SCRIPTS)/klayout/abstract_gds.py | $(ABS)
	cd $(BUILD) && $(KLAYOUT) -zz -rd in_gds=final.gds -rd cells_gds="$(CELL_GDS)" -rd top=$(TOP) -rd out=$@ \
	  -r $(SCRIPTS)/klayout/abstract_gds.py > abstract_gds.log 2>&1 || { tail -5 abstract_gds.log; exit 1; }

$(ABS)/$(TOP).cdl: $(BUILD)/finish.done $(CDL_FILE) $(MACRO_CDL) $(SCRIPTS)/klayout/v2cdl.py | $(ABS)
	python3 $(SCRIPTS)/klayout/v2cdl.py $(BUILD)/final_lvs.v --top $(TOP) $(addprefix --cdl ,$(CDL_FILE) $(MACRO_CDL)) -o $@

$(ABS)/$(TOP).v: $(BUILD)/finish.done | $(ABS)
	cp $(BUILD)/final_logic.v $@
