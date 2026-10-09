# File:        Makefile
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: SiliconBadgers RTL-to-GDS flow on sky130_scl_9T with Cadence tools: lint, sim, synth, sta, floorplan, place, cts, grt, route, finish, gds, drc, lvs. Run `make help` for usage.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SECONDARY:

SB_ROOT  := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
FLOW     := $(SB_ROOT)/flow
SCRIPTS  := $(FLOW)/scripts
DESIGN   ?= gcd

# tools (on PATH by default; a value may start with a site wrapper command)
XRUN     ?= xrun
GENUS    ?= genus
INNOVUS  ?= innovus
TEMPUS   ?= tempus
VOLTUS   ?= voltus
PEGASUS  ?= pegasus
GENUS_FLAGS   ?= -no_gui
INNOVUS_FLAGS ?= -stylus -nowin
TEMPUS_FLAGS  ?= -stylus -no_gui
VOLTUS_FLAGS  ?= -stylus -no_gui
# CPU cores per tool
NCPU     ?= 4

# --- synthesis and simulation settings ---
# Genus effort for syn_generic, syn_map and syn_opt: low, medium or high
SYNTH_EFFORT ?= medium
WAVES        ?= 0

PLATFORM_MK := $(FLOW)/platforms/sky130_scl_9T.mk
include $(PLATFORM_MK)

DESIGN_DIR := $(SB_ROOT)/designs/$(DESIGN)
ifeq ($(wildcard $(DESIGN_DIR)/design.mk),)
  $(error DESIGN=$(DESIGN): no designs/$(DESIGN)/design.mk)
endif
include $(DESIGN_DIR)/design.mk

# --- optional design.mk settings ---
RTL_INCDIRS      ?=
RTL_DEFINES      ?=
TB_SOURCES       ?=
LINT_WAIVERS     ?= $(wildcard $(DESIGN_DIR)/hal_waivers.txt)
CORE_UTILIZATION ?= 40
ASPECT_RATIO     ?= 1
CORE_MARGIN      ?= 10
PLACE_DENSITY    ?= 0.60
IO_CONSTRAINTS   ?=
GPL_TIMING_DRIVEN ?= 1
CTS_BUF_LIST     ?= CLKBUFX2 CLKBUFX4 CLKBUFX8
# none = buffers only
CTS_INV_LIST     ?= CLKINVX1 CLKINVX2 CLKINVX4 CLKINVX8
SKIP_CTS_REPAIR_TIMING ?= 0
# um between VDD/VSS strap pairs (met4 and met5)
PDN_STRAP_PITCH  ?= 50
# corners for setup and for hold (Innovus and Tempus)
# tt by default, like track-a; add ss/ff for full signoff
SETUP_CORNERS    ?= tt
HOLD_CORNERS     ?= tt
# Quantus effort in finish: signoff (standalone Quantus), high, medium or low
EXTRACT_EFFORT   ?= signoff
# 1 = finish skips the Voltus IR-drop step
SKIP_IR          ?= 0
# 1 = Pegasus also checks metal density (fails without metal fill)
DRC_DENSITY      ?= 0

# run name; each variant keeps its own build directory
VARIANT ?= base
BUILD   ?= $(SB_ROOT)/build/$(DESIGN)/$(VARIANT)
TIMES   := $(BUILD)/runtimes.txt
TIMED   := $(SCRIPTS)/util/timed.sh $(TIMES)
# Voltus power-grid view of the library (the PDK ships none), built once
PGV_DIR ?= $(SB_ROOT)/build/pgv
PGV     := $(PGV_DIR)/techonly.cl

FLOW_DEPS := $(PLATFORM_MK) $(DESIGN_DIR)/design.mk

# --- targets ---
.PHONY: help info all lint sim synth sta floorplan place cts grt route finish gds drc lvs clean FORCE
FORCE:
help:
	@echo "usage: make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]"
	@echo "  stages:  lint sim synth sta floorplan place cts grt route finish gds drc lvs | all | clean | info"
	@echo "  DESIGN:  $(notdir $(wildcard $(SB_ROOT)/designs/*))"
	@echo "  info:    settings, tools found on PATH, PDK files present"
	@echo "outputs: build/<DESIGN>/<VARIANT>/"

info:
	@echo "DESIGN=$(DESIGN) TOP=$(TOP) SDC=$(SDC_FILE)"
	@echo "PDK=$(PLATFORM_DIR)"
	@echo "BUILD=$(BUILD)"
	@echo "setup corners: $(SETUP_CORNERS)  hold corners: $(HOLD_CORNERS)"
	@for t in $(foreach v,XRUN GENUS INNOVUS TEMPUS VOLTUS PEGASUS,$(firstword $($(v)))) qrc python3; do \
	  printf '%-8s ' $$t; command -v $$t || echo MISSING; done
	@for f in $(LIB_ss) $(LIB_tt) $(LIB_ff) $(LIB_EXTRA) $(TECH_LEF) $(CELL_LEF) $(CELL_GDS) $(CELL_CDL) \
	  $(STREAM_MAP) $(QRC_TECH) $(DRC_DECK) $(LVS_DECK); do test -e $$f && echo "OK      $$f" || echo "MISSING $$f"; done

print-%:
	@echo '$($*)'

all: lint sim synth sta floorplan place cts grt route finish gds drc lvs

lint:      $(BUILD)/lint.log
sim:       $(BUILD)/results.xml
synth:     $(BUILD)/netlist.v
sta:       $(BUILD)/sta.json
floorplan: $(BUILD)/floorplan.json
place:     $(BUILD)/place.json
cts:       $(BUILD)/cts.json
grt:       $(BUILD)/grt.json
route:     $(BUILD)/route.json
finish:    $(BUILD)/finish.json
gds:       $(BUILD)/final.gds
drc:       $(BUILD)/drc_count.txt
lvs:       $(BUILD)/lvs.rpt

clean:
	rm -rf $(BUILD)

$(BUILD):
	mkdir -p $@

# --- lint (Xcelium HAL; a warning fails unless hal_waivers.txt waives it) ---
$(BUILD)/lint.log: $(RTL_FILES) $(LINT_WAIVERS) $(FLOW_DEPS) $(SCRIPTS)/lint/hal_check.py | $(BUILD)
	mkdir -p $(BUILD)/lint
	cd $(BUILD)/lint && rc=0 && \
	  { $(TIMED) lint $(XRUN) -hal -sv -top $(TOP) $(addprefix -incdir ,$(RTL_INCDIRS)) \
	    $(addprefix -define ,$(RTL_DEFINES)) $(RTL_FILES) < /dev/null > hal.log 2>&1 || rc=$$?; } && \
	  echo "SB: xrun exit status $$rc" >> hal.log
	python3 $(SCRIPTS)/lint/hal_check.py $(BUILD)/lint/hal.log $(LINT_WAIVERS) > $@.tmp || \
	  { cat $@.tmp; rm -f $@.tmp; echo "lint FAILED -- read $(BUILD)/lint/hal.log"; exit 1; }
	@mv $@.tmp $@ && cat $@

# --- sim (cocotb on the RTL, Xcelium) ---
$(BUILD)/results.xml: $(RTL_FILES) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) $(FLOW_DEPS) $(SCRIPTS)/sim/run_cocotb.py | $(BUILD)
	$(TIMED) sim python3 $(SCRIPTS)/sim/run_cocotb.py --toplevel $(TOP) --test-module $(TB_MODULE) --test-dir $(TB_DIR) \
	  --build-dir $(BUILD)/sim_rtl --results $@ --waves $(WAVES) \
	  $(addprefix --incdir ,$(RTL_INCDIRS)) $(addprefix --define ,$(RTL_DEFINES)) \
	  --sources $(RTL_FILES) $(TB_SOURCES)

# --- inputs for the Tcl scripts; an env file is replaced only when its content changes ---
# corners, libraries and SDC for flow/scripts/mmmc.tcl (Genus, Innovus, Tempus)
MMMC_ENV = \
  echo "export SCRIPTS='$(SCRIPTS)' OUT_DIR='$(BUILD)' TOP='$(TOP)' NCPU='$(NCPU)'"; \
  echo "export SDC_FILE='$(SDC_FILE)'"; \
  echo "export LIB_ss='$(LIB_ss)' LIB_tt='$(LIB_tt)' LIB_ff='$(LIB_ff)' LIB_EXTRA='$(LIB_EXTRA)'"; \
  echo "export QRC_TECH='$(QRC_TECH)' QRC_LAYER_MAP='$(QRC_LAYER_MAP)'"; \
  echo "export SETUP_CORNERS='$(SETUP_CORNERS)' HOLD_CORNERS='$(HOLD_CORNERS)'"; \
  echo "export TECH_LEF='$(TECH_LEF)' CELL_LEF='$(CELL_LEF)'";
write_env = { $(1) } > $@.tmp; cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

$(BUILD)/synth.env: FORCE | $(BUILD)
	@$(call write_env, echo "# Inputs for flow/scripts/genus/synth.tcl and the pre-layout sta (generated by make)"; \
	  $(MMMC_ENV) \
	  echo "export RTL_FILES='$(RTL_FILES)' RTL_INCDIRS='$(RTL_INCDIRS)' RTL_DEFINES='$(RTL_DEFINES)'"; \
	  echo "export DONT_USE='$(DONT_USE)' TIEHI_CELL='$(TIEHI_CELL)' TIELO_CELL='$(TIELO_CELL)'"; \
	  echo "export SYNTH_EFFORT='$(SYNTH_EFFORT)'";)

$(BUILD)/pnr.env: FORCE | $(BUILD)
	@$(call write_env, echo "# Inputs for the place-and-route and sign-off scripts (generated by make)"; \
	  $(MMMC_ENV) \
	  echo "export NETLIST='$(BUILD)/netlist.v'"; \
	  echo "export SITE='$(SITE)' FILL_CELLS='$(FILL_CELLS)' DECAP_CELLS='$(DECAP_CELLS)'"; \
	  echo "export TIEHI_CELL='$(TIEHI_CELL)' TIELO_CELL='$(TIELO_CELL)'"; \
	  echo "export MIN_ROUTING_LAYER='$(MIN_ROUTING_LAYER)' MAX_ROUTING_LAYER='$(MAX_ROUTING_LAYER)'"; \
	  echo "export MIN_CLK_ROUTING_LAYER='$(MIN_CLK_ROUTING_LAYER)' MAX_CLK_ROUTING_LAYER='$(MAX_CLK_ROUTING_LAYER)'"; \
	  echo "export PWR_NET='$(PWR_NET)' GND_NET='$(GND_NET)' VDD_V='$(VDD_V)'"; \
	  echo "export CORE_UTILIZATION='$(CORE_UTILIZATION)' ASPECT_RATIO='$(ASPECT_RATIO)' CORE_MARGIN='$(CORE_MARGIN)'"; \
	  echo "export PLACE_DENSITY='$(PLACE_DENSITY)' GPL_TIMING_DRIVEN='$(GPL_TIMING_DRIVEN)'"; \
	  echo "export IO_CONSTRAINTS='$(abspath $(IO_CONSTRAINTS))' PDN_STRAP_PITCH='$(PDN_STRAP_PITCH)'"; \
	  echo "export CTS_BUF_LIST='$(CTS_BUF_LIST)' CTS_INV_LIST='$(CTS_INV_LIST)'"; \
	  echo "export SKIP_CTS_REPAIR_TIMING='$(SKIP_CTS_REPAIR_TIMING)' EXTRACT_EFFORT='$(EXTRACT_EFFORT)'"; \
	  echo "export STREAM_MAP='$(STREAM_MAP)' CELL_GDS='$(CELL_GDS)' PGV_DIR='$(PGV_DIR)'";)

# --- Cadence tool runs ---
# $(call cadence,<step>,<env file>,<command>): run the command in the build directory, output in <step>.log.
# Cadence tools do not always exit non-zero on a script error, so the step passes only if its script printed "SB: <name> done".
cadence = cd $(BUILD) && source $(2) && mkdir -p logs && \
  { $(TIMED) $(1) $(3) < /dev/null > $(1).log 2>&1 || true; } && \
  if grep -qE '^SB: [a-z_]+ done$$' $(1).log; then grep -E '^SB(-WARNING)?:' $(1).log | grep -vE ' done$$' || true; \
  else grep -E '^\*\*ERROR|^Error|^SB-ERROR' $(1).log | head -5 || true; \
    echo "$(1) FAILED -- read $(BUILD)/$(1).log (the first ERROR)"; exit 1; fi
genus   = $(GENUS) $(GENUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/genus/$(1).tcl
innovus = $(INNOVUS) $(INNOVUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/pnr/$(1).tcl
tempus  = $(TEMPUS) $(TEMPUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/tempus/sta.tcl
voltus  = $(VOLTUS) $(VOLTUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/voltus/$(2).tcl

# --- synth (Genus), then the latch, loop and missing-cell check ---
$(BUILD)/netlist.v: $(BUILD)/synth.env $(RTL_FILES) $(SDC_FILE) $(FLOW_DEPS) $(SCRIPTS)/genus/synth.tcl \
                    $(SCRIPTS)/mmmc.tcl $(SCRIPTS)/util/sb_util.tcl $(SCRIPTS)/genus/synth_check.py
	rm -f $@
	$(call cadence,synth,synth.env,$(call genus,synth))
	python3 $(SCRIPTS)/genus/synth_check.py --build $(BUILD) --latch-cells "$(LATCH_CELLS)"

# --- sta (Tempus, pre-layout: ideal clocks, no wire parasitics) ---
$(BUILD)/sta.json: $(BUILD)/netlist.v $(BUILD)/synth.env $(SCRIPTS)/tempus/sta.tcl $(SCRIPTS)/mmmc.tcl
	rm -f $@
	$(call cadence,sta,synth.env,env STA_STAGE=sta NETLIST=$(BUILD)/netlist.v $(call tempus,sta))

# --- place and route (one Innovus run per stage: <stage>.db, .log, .rpt, .json) ---
PNR_DEPS := $(BUILD)/pnr.env $(SDC_FILE) $(SCRIPTS)/pnr/common.tcl $(SCRIPTS)/mmmc.tcl $(SCRIPTS)/util/sb_util.tcl
pnr_stage = rm -f $(BUILD)/$(1).json && $(call cadence,$(1),pnr.env,$(call innovus,$(1)))

$(BUILD)/floorplan.json: $(BUILD)/netlist.v $(PNR_DEPS) $(SCRIPTS)/pnr/floorplan.tcl $(SCRIPTS)/pnr/power.tcl $(IO_CONSTRAINTS)
	$(call pnr_stage,floorplan)
$(BUILD)/place.json: $(BUILD)/floorplan.json $(PNR_DEPS) $(SCRIPTS)/pnr/place.tcl
	$(call pnr_stage,place)
$(BUILD)/cts.json: $(BUILD)/place.json $(PNR_DEPS) $(SCRIPTS)/pnr/cts.tcl
	$(call pnr_stage,cts)
$(BUILD)/grt.json: $(BUILD)/cts.json $(PNR_DEPS) $(SCRIPTS)/pnr/grt.tcl
	$(call pnr_stage,grt)
$(BUILD)/route.json: $(BUILD)/grt.json $(PNR_DEPS) $(SCRIPTS)/pnr/route.tcl
	$(call pnr_stage,route)

# finish: Innovus (fill, Quantus extraction, netlists), Tempus (sign-off timing), Voltus (IR drop)
$(BUILD)/finish.json: $(BUILD)/route.json $(PNR_DEPS) $(SCRIPTS)/pnr/finish.tcl $(SCRIPTS)/tempus/sta.tcl \
                      $(SCRIPTS)/tempus/propagated.sdc $(SCRIPTS)/voltus/ir.tcl | $(if $(filter 1,$(SKIP_IR)),,$(PGV))
	$(call pnr_stage,finish)
	$(call cadence,finish_sta,pnr.env,env STA_STAGE=finish STA_NAME=finish_sta NETLIST=$(BUILD)/final.v \
	  SPEF_PREFIX=$(BUILD)/final PROP_SDC=$(SCRIPTS)/tempus/propagated.sdc $(call tempus,finish_sta))
	$(if $(filter 1,$(SKIP_IR)),echo "IR drop skipped (SKIP_IR=1)",$(call cadence,finish_ir,pnr.env,$(call voltus,finish_ir,ir)))

$(PGV): | $(BUILD)/pnr.env
	mkdir -p $(PGV_DIR)/logs
	cd $(PGV_DIR) && source $(BUILD)/pnr.env && \
	  { $(call voltus,pgv,pgv) < /dev/null > pgv.log 2>&1 || true; }
	@test -e $@ || { tail -20 $(PGV_DIR)/pgv.log; echo "pgv FAILED -- read $(PGV_DIR)/pgv.log"; exit 1; }

# --- layout: GDS with the cell layouts merged in (Innovus) ---
$(BUILD)/final.gds: $(BUILD)/finish.json $(BUILD)/pnr.env $(SCRIPTS)/pnr/gds.tcl
	rm -f $@
	$(call cadence,gds,pnr.env,$(call innovus,gds))

# --- signoff checks (Pegasus) ---
PEGASUS_ENV = env PEGASUS='$(PEGASUS)' NCPU='$(NCPU)'
$(BUILD)/drc_count.txt: $(BUILD)/final.gds $(SCRIPTS)/pegasus/drc.sh
	cd $(BUILD) && $(TIMED) drc $(PEGASUS_ENV) DRC_DENSITY='$(DRC_DENSITY)' $(SCRIPTS)/pegasus/drc.sh \
	  $(DRC_DECK) final.gds $(TOP) drc $@ > drc.log 2>&1 || { tail -5 drc.log; echo "DRC FAILED -- read $(BUILD)/drc.log"; exit 1; }
	@echo "Pegasus DRC violations: $$(cat $@) (results in $(BUILD)/drc/)"

$(BUILD)/lvs.rpt: $(BUILD)/final.gds $(SCRIPTS)/pegasus/lvs.sh
	cd $(BUILD) && $(TIMED) lvs $(PEGASUS_ENV) $(SCRIPTS)/pegasus/lvs.sh $(LVS_DECK) final.gds $(TOP) lvs \
	  final_lvs.v $(CELL_CDL) > lvs.log 2>&1 || { tail -5 lvs.log; echo "LVS FAILED -- read $(BUILD)/lvs.log"; exit 1; }
	@r=$(BUILD)/lvs/$(TOP).lvs.rpt; grep -qE '\bMATCH\b' $$r && ! grep -qE 'MISMATCH' $$r && cp $$r $@ && \
	  echo "LVS: layout matches netlist" || { echo "LVS FAILED -- read $$r"; exit 1; }
