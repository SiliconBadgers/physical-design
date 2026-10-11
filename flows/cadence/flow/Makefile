# File:        Makefile
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: SiliconBadgers RTL-to-GDS flow on sky130_scl_9T with Cadence tools: lint, sim, synth, sta, floorplan, place, cts, grt, route, finish, gds, drc, lvs, lec, gls, abstract. Run `make help` for usage.

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
LEC      ?= lec
GENUS_FLAGS   ?= -no_gui
INNOVUS_FLAGS ?= -stylus -nowin
TEMPUS_FLAGS  ?= -stylus -no_gui
VOLTUS_FLAGS  ?= -stylus -no_gui
LEC_FLAGS     ?= -xl -nogui
# CPU cores per tool
NCPU     ?= 4

# --- synthesis and simulation settings ---
# Genus effort for syn_generic, syn_map and syn_opt: low, medium or high
SYNTH_EFFORT ?= medium
WAVES        ?= 0
# wall-clock limit of one sim or gls run in seconds; a normal run takes well under a minute
SIM_TIMEOUT ?= 900
# Conformal RTL vs netlist: genus = the dofile Genus wrote (genus_lec.do), own = flow/scripts/lec/lec_synth.do
LEC_SYNTH_MODE ?= genus
# xrun options for gls: the cell models have zero delay, so each flip-flop gets a clock-to-Q delay (no race with the clock tree's delta cycles)
GLS_XRUN_ARGS  ?= -seq_udp_delay 50ps

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
MACRO_VERILOG    ?=
MACRO_SIM_MODELS ?=
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
# power grid script sourced by floorplan.tcl
PDN_TCL          ?= $(SCRIPTS)/pnr/power.tcl
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
# hard macros: designs built first and used as abstracts (design.mk: MACROS := <design> ...)
MACROS        ?=
MACRO_VARIANT ?= base
macro_abs      = $(SB_ROOT)/build/$(1)/$(MACRO_VARIANT)/abstract/$(1)
# timing models of the macros at one corner
macro_libs     = $(foreach m,$(MACROS),$(call macro_abs,$(m))_$(1).lib)
MACRO_LIBS    := $(foreach c,$(CORNERS),$(call macro_libs,$(c)))
MACRO_LEFS    := $(foreach m,$(MACROS),$(call macro_abs,$(m)).lef)
MACRO_GDS     := $(foreach m,$(MACROS),$(call macro_abs,$(m)).gds)
# netlists for LVS, and routed logic netlists for gate-level simulation
MACRO_LVS     := $(foreach m,$(MACROS),$(call macro_abs,$(m))_lvs.v)
MACRO_NETLISTS := $(foreach m,$(MACROS),$(call macro_abs,$(m)).v)
MACRO_FILES   := $(MACRO_LEFS) $(MACRO_LIBS) $(MACRO_GDS) $(MACRO_LVS) $(MACRO_NETLISTS)
# placement keep-out for standard cells around each macro, and minimum channel between macros and to the core edge (um)
MACRO_HALO    ?= 10
MACRO_CHANNEL ?= 80

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
.PHONY: help info all lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls lec-mutation abstract macros clean FORCE
# stages run in order (macros are built before synthesis)
.NOTPARALLEL:
FORCE:
help:
	@echo "usage: make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]"
	@echo "  stages:  lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls | abstract | all | clean | info"
	@echo "  DESIGN:  $(notdir $(wildcard $(SB_ROOT)/designs/*))"
	@echo "  info:    settings, tools found on PATH, PDK files present"
	@echo "  lec-mutation: LEC must fail on broken netlists"
	@echo "outputs: build/<DESIGN>/<VARIANT>/"

info:
	@echo "DESIGN=$(DESIGN) TOP=$(TOP) SDC=$(SDC_FILE)"
	@echo "PDK=$(PLATFORM_DIR)"
	@echo "BUILD=$(BUILD)"
	@echo "setup corners: $(SETUP_CORNERS)  hold corners: $(HOLD_CORNERS)"
	@for t in $(foreach v,XRUN GENUS INNOVUS TEMPUS VOLTUS PEGASUS LEC,$(firstword $($(v)))) qrc python3; do \
	  printf '%-8s ' $$t; command -v $$t || echo MISSING; done
	@for f in $(LIB_ss) $(LIB_tt) $(LIB_ff) $(LIB_EXTRA) $(TECH_LEF) $(CELL_LEF) $(CELL_GDS) $(CELL_CDL) \
	  $(STREAM_MAP) $(QRC_TECH) $(DRC_DECK) $(LVS_DECK) $(CELL_VERILOG); do test -e $$f && echo "OK      $$f" || echo "MISSING $$f"; done

print-%:
	@echo '$($*)'

all: lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls

lint:      $(BUILD)/lint.log
sim:       $(if $(TB_MODULE),$(BUILD)/results.xml)
synth:     macros $(BUILD)/netlist.v
sta:       macros $(BUILD)/sta.json
floorplan: macros $(BUILD)/floorplan.json
place:     macros $(BUILD)/place.json
cts:       macros $(BUILD)/cts.json
grt:       macros $(BUILD)/grt.json
route:     macros $(BUILD)/route.json
finish:    macros $(BUILD)/finish.json
gds:       macros $(BUILD)/final.gds
drc:       macros $(BUILD)/drc_count.txt
lvs:       macros $(BUILD)/lvs.rpt
lec:       macros $(BUILD)/lec_synth.rpt $(BUILD)/lec_route.rpt
gls:       macros $(if $(TB_MODULE),$(BUILD)/gls_results.xml)
abstract:  macros $(BUILD)/abstract/$(TOP).lef $(BUILD)/abstract/$(TOP).gds

# build each macro's abstract in its own make: no command-line settings (make exports them too) except the tools, PDK, NCPU and -n
MACRO_MAKE_VARS := SB_PDK NCPU GENUS INNOVUS TEMPUS VOLTUS GENUS_FLAGS INNOVUS_FLAGS TEMPUS_FLAGS VOLTUS_FLAGS
cmdline_vars     = $(strip $(foreach v,$(.VARIABLES),$(if $(filter command line,$(origin $(v))),$(v))))
macros:
	@$(foreach m,$(MACROS),env -u MAKEFLAGS -u MFLAGS $(addprefix -u ,$(cmdline_vars)) \
	  $(MAKE) --no-print-directory $(if $(findstring n,$(firstword -$(MAKEFLAGS))),-n) -C $(SB_ROOT) abstract \
	  DESIGN=$(m) VARIANT=$(MACRO_VARIANT) $(foreach v,$(MACRO_MAKE_VARS),$(v)='$($(v))') &&) true
$(MACRO_FILES): ;

clean:
	rm -rf $(BUILD)

$(BUILD):
	mkdir -p $@

# --- lint (Xcelium HAL; a warning fails unless hal_waivers.txt waives it) ---
$(BUILD)/lint.log: $(RTL_FILES) $(MACRO_VERILOG) $(LINT_WAIVERS) $(FLOW_DEPS) $(SCRIPTS)/lint/hal_check.py | $(BUILD)
	mkdir -p $(BUILD)/lint
	cd $(BUILD)/lint && rm -f hal.log && rc=0 && \
	  { $(TIMED) lint $(XRUN) -hal -sv -top $(TOP) $(addprefix -incdir ,$(RTL_INCDIRS)) \
	    $(addprefix -define ,$(RTL_DEFINES)) $(RTL_FILES) $(MACRO_VERILOG) -l hal.log < /dev/null > hal_stdout.log 2>&1 || rc=$$?; } && \
	  echo "SB: xrun exit status $$rc" >> hal.log
	python3 $(SCRIPTS)/lint/hal_check.py $(BUILD)/lint/hal.log $(LINT_WAIVERS) > $@.tmp || \
	  { cat $@.tmp; rm -f $@.tmp; echo "lint FAILED -- read $(BUILD)/lint/hal.log"; exit 1; }
	@mv $@.tmp $@ && cat $@

# --- sim (cocotb on the RTL, Xcelium) ---
$(BUILD)/results.xml: $(RTL_FILES) $(MACRO_SIM_MODELS) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) $(FLOW_DEPS) $(SCRIPTS)/sim/run_cocotb.py | $(BUILD)
	$(TIMED) sim python3 $(SCRIPTS)/sim/run_cocotb.py --timeout $(SIM_TIMEOUT) --toplevel $(TOP) --test-module $(TB_MODULE) --test-dir $(TB_DIR) \
	  --build-dir $(BUILD)/sim_rtl --results $@ --waves $(WAVES) \
	  $(addprefix --incdir ,$(RTL_INCDIRS)) $(addprefix --define ,$(RTL_DEFINES)) \
	  --sources $(RTL_FILES) $(MACRO_SIM_MODELS) $(TB_SOURCES)
	$(LOG_CHECK) sim $(BUILD)/sim_rtl/xrun_build.log $(BUILD)/sim_rtl/xrun_test.log

# --- inputs for the Tcl scripts; an env file is replaced only when its content changes ---
# corners, libraries and SDC for flow/scripts/mmmc.tcl (Genus, Innovus, Tempus)
MMMC_ENV = \
  echo "export SCRIPTS='$(SCRIPTS)' OUT_DIR='$(BUILD)' TOP='$(TOP)' NCPU='$(NCPU)'"; \
  echo "export SDC_FILE='$(SDC_FILE)'"; \
  echo "export LIB_ss='$(LIB_ss)' LIB_tt='$(LIB_tt)' LIB_ff='$(LIB_ff)' LIB_EXTRA='$(LIB_EXTRA)'"; \
  echo "export QRC_TECH='$(QRC_TECH)' QRC_LAYER_MAP='$(QRC_LAYER_MAP)'"; \
  echo "export SETUP_CORNERS='$(SETUP_CORNERS)' HOLD_CORNERS='$(HOLD_CORNERS)'"; \
  echo "export TECH_LEF='$(TECH_LEF)' CELL_LEF='$(CELL_LEF)' MACRO_LEFS='$(MACRO_LEFS)'"; \
  echo "export MACRO_LIB_ss='$(call macro_libs,ss)' MACRO_LIB_tt='$(call macro_libs,tt)' MACRO_LIB_ff='$(call macro_libs,ff)'";
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
	  echo "export SITE='$(SITE)' FILL_CELLS='$(FILL_CELLS)' DECAP_CELLS='$(DECAP_CELLS)' ANTENNA_CELL='$(ANTENNA_CELL)'"; \
	  echo "export TIEHI_CELL='$(TIEHI_CELL)' TIELO_CELL='$(TIELO_CELL)'"; \
	  echo "export MIN_ROUTING_LAYER='$(MIN_ROUTING_LAYER)' MAX_ROUTING_LAYER='$(MAX_ROUTING_LAYER)'"; \
	  echo "export MIN_CLK_ROUTING_LAYER='$(MIN_CLK_ROUTING_LAYER)' MAX_CLK_ROUTING_LAYER='$(MAX_CLK_ROUTING_LAYER)'"; \
	  echo "export PWR_NET='$(PWR_NET)' GND_NET='$(GND_NET)' VDD_V='$(VDD_V)'"; \
	  echo "export CORE_UTILIZATION='$(CORE_UTILIZATION)' ASPECT_RATIO='$(ASPECT_RATIO)' CORE_MARGIN='$(CORE_MARGIN)'"; \
	  echo "export PLACE_DENSITY='$(PLACE_DENSITY)' GPL_TIMING_DRIVEN='$(GPL_TIMING_DRIVEN)'"; \
	  echo "export IO_CONSTRAINTS='$(abspath $(IO_CONSTRAINTS))' PDN_STRAP_PITCH='$(PDN_STRAP_PITCH)'"; \
	  echo "export CTS_BUF_LIST='$(CTS_BUF_LIST)' CTS_INV_LIST='$(CTS_INV_LIST)'"; \
	  echo "export SKIP_CTS_REPAIR_TIMING='$(SKIP_CTS_REPAIR_TIMING)' EXTRACT_EFFORT='$(EXTRACT_EFFORT)'"; \
	  echo "export STREAM_MAP='$(STREAM_MAP)' CELL_GDS='$(CELL_GDS)' PGV_DIR='$(PGV_DIR)'"; \
	  echo "export PDN_TCL='$(PDN_TCL)' MACROS='$(MACROS)' MACRO_GDS='$(MACRO_GDS)' MACRO_TOP_LAYER='$(MACRO_TOP_LAYER)'"; \
	  echo "export MACRO_HALO='$(MACRO_HALO)' MACRO_CHANNEL='$(MACRO_CHANNEL)' MACRO_GRID='$(MACRO_GRID)'"; \
	  echo "export PHYSICAL_CELLS='$(PHYSICAL_CELLS)'";)

$(BUILD)/lec.env: FORCE | $(BUILD)
	@$(call write_env, echo "# Inputs for the Conformal dofiles in flow/scripts/lec/ (generated by make)"; \
	  $(MMMC_ENV) \
	  echo "export RTL_FILES='$(RTL_FILES)' RTL_INCDIRS='$(RTL_INCDIRS)' RTL_DEFINES='$(RTL_DEFINES)'"; \
	  echo "export MACROS='$(MACROS)' LEC_SYNTH_MODE='$(LEC_SYNTH_MODE)'";)

# --- Cadence tool runs ---
# $(call cadence,<step>,<env file>,<command>): run the command in the build directory, output in <step>.log.
# Cadence tools do not always exit non-zero on a script error, so the step passes only if its script printed "SB: <name> done"
# and the log has no tool error line (LOG_CHECK; harmless errors are waived by message ID in flow/scripts/util/log_waivers.txt).
LOG_CHECK := $(SCRIPTS)/util/log_check.sh
cadence = cd $(BUILD) && source $(2) && mkdir -p logs && \
  { $(TIMED) $(1) $(3) < /dev/null > $(1).log 2>&1 || true; } && \
  if grep -qE '^SB: [a-z_]+ done$$' $(1).log; then grep -E '^SB(-WARNING)?:' $(1).log | grep -vE ' done$$' || true; \
  else grep -E '^\*\*ERROR|^Error|^SB-ERROR' $(1).log | head -5 || true; \
    echo "$(1) FAILED -- read $(BUILD)/$(1).log (the first ERROR)"; exit 1; fi && \
  $(LOG_CHECK) $(1) $(BUILD)/$(1).log
genus   = $(GENUS) $(GENUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/genus/$(1).tcl
innovus = $(INNOVUS) $(INNOVUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/pnr/$(1).tcl
tempus  = $(TEMPUS) $(TEMPUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/tempus/sta.tcl
voltus  = $(VOLTUS) $(VOLTUS_FLAGS) -log logs/$(1) -files $(SCRIPTS)/voltus/$(2).tcl

# --- synth (Genus), then the latch, loop and missing-cell check ---
$(BUILD)/netlist.v: $(BUILD)/synth.env $(RTL_FILES) $(MACRO_LIBS) $(MACRO_LEFS) $(SDC_FILE) $(FLOW_DEPS) $(SCRIPTS)/genus/synth.tcl \
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

$(BUILD)/floorplan.json: $(BUILD)/netlist.v $(MACRO_LEFS) $(PNR_DEPS) $(SCRIPTS)/pnr/floorplan.tcl $(PDN_TCL) $(IO_CONSTRAINTS)
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
	$(LOG_CHECK) pgv $(PGV_DIR)/pgv.log

# --- abstract of this design for use as a macro: LEF, timing model per corner, logic and LVS netlists; GDS copied on its own ---
$(BUILD)/abstract/$(TOP).lef: $(BUILD)/finish.json $(PNR_DEPS) $(SCRIPTS)/pnr/abstract.tcl
	$(call pnr_stage,abstract)
	cp $(BUILD)/final_logic.v $(BUILD)/abstract/$(TOP).v
	cp $(BUILD)/final_lvs.v $(BUILD)/abstract/$(TOP)_lvs.v
$(BUILD)/abstract/$(TOP).gds: $(BUILD)/final.gds
	mkdir -p $(@D)
	cp $< $@

# --- layout: GDS with the cell and macro layouts merged in (Innovus) ---
$(BUILD)/final.gds: $(BUILD)/finish.json $(MACRO_GDS) $(BUILD)/pnr.env $(SCRIPTS)/pnr/gds.tcl
	rm -f $@
	$(call cadence,gds,pnr.env,$(call innovus,gds))

# --- signoff checks (Pegasus) ---
PEGASUS_ENV = env PEGASUS='$(PEGASUS)' NCPU='$(NCPU)'
$(BUILD)/drc_count.txt: $(BUILD)/final.gds $(SCRIPTS)/pegasus/drc.sh
	cd $(BUILD) && $(TIMED) drc $(PEGASUS_ENV) DRC_DENSITY='$(DRC_DENSITY)' $(SCRIPTS)/pegasus/drc.sh \
	  $(DRC_DECK) final.gds $(TOP) drc $@ > drc.log 2>&1 || { tail -5 drc.log; echo "DRC FAILED -- read $(BUILD)/drc.log"; exit 1; }
	@echo "Pegasus DRC violations: $$(cat $@) (results in $(BUILD)/drc/)"

$(BUILD)/lvs.rpt: $(BUILD)/final.gds $(MACRO_LVS) $(SCRIPTS)/pegasus/lvs.sh
	cd $(BUILD) && $(TIMED) lvs $(PEGASUS_ENV) $(SCRIPTS)/pegasus/lvs.sh $(LVS_DECK) final.gds $(TOP) lvs \
	  final_lvs.v $(CELL_CDL) $(MACRO_LVS) > lvs.log 2>&1 || { tail -5 lvs.log; echo "LVS FAILED -- read $(BUILD)/lvs.log"; exit 1; }
	@r=$(BUILD)/lvs/$(TOP).lvs.rpt; grep -qE '\bMATCH\b' $$r && ! grep -qE 'MISMATCH' $$r && cp $$r $@ && \
	  echo "LVS: layout matches netlist" || { echo "LVS FAILED -- read $$r"; exit 1; }

# --- lec (Conformal): RTL vs netlist.v, then netlist.v vs the routed final_logic.v; hard macros are black boxes ---
# dofile per step (chosen when the recipe runs): the RTL step runs the one Genus wrote, unless LEC_SYNTH_MODE=own or there is none
lec_do_synth = $$([ "$(LEC_SYNTH_MODE)" = genus ] && [ -s $(BUILD)/genus_lec.do ] && echo $(BUILD)/genus_lec.do || echo $(SCRIPTS)/lec/lec_synth.do)
lec_do_route = $(SCRIPTS)/lec/lec_route.do
$(BUILD)/lec_synth.rpt: $(BUILD)/netlist.v $(SCRIPTS)/lec/lec_synth.do $(MACRO_LIBS)
$(BUILD)/lec_route.rpt: $(BUILD)/netlist.v $(BUILD)/finish.json $(SCRIPTS)/lec/lec_route.do $(MACRO_LIBS)
$(BUILD)/lec_%.rpt: $(BUILD)/lec.env $(SCRIPTS)/lec/lec_common.tcl $(SCRIPTS)/lec/lec_result.py
	rm -f $@
	cd $(BUILD) && source lec.env && mkdir -p logs && \
	  { $(TIMED) lec_$* $(LEC) $(LEC_FLAGS) -dofile $(lec_do_$*) < /dev/null > lec_$*.log 2>&1 || true; }
	@python3 $(SCRIPTS)/lec/lec_result.py $* $(BUILD)/lec_$*.log | tee $@.tmp && mv $@.tmp $@ || \
	  { rm -f $@.tmp; echo "LEC $* FAILED -- read $(BUILD)/lec_$*.log"; exit 1; }

# LEC must still fail on broken netlists: two mutants for each LEC step
lec-mutation: macros $(BUILD)/lec.env $(BUILD)/netlist.v $(BUILD)/finish.json $(SCRIPTS)/lec/lec_mutation.py
	cd $(BUILD) && source lec.env && python3 $(SCRIPTS)/lec/lec_mutation.py --work $(BUILD)/lec_mutation --cmd "$(LEC) $(LEC_FLAGS)" \
	  --check synth $(lec_do_synth) $(BUILD)/netlist.v --check route $(lec_do_route) $(BUILD)/final_logic.v

# --- gls: the RTL testbench on the routed logic netlist with the cell models; hard macros simulate their routed netlists ---
$(BUILD)/gls_results.xml: $(BUILD)/finish.json $(CELL_VERILOG) $(MACRO_NETLISTS) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) \
                          $(FLOW_DEPS) $(SCRIPTS)/sim/run_cocotb.py
	$(TIMED) gls python3 $(SCRIPTS)/sim/run_cocotb.py --timeout $(SIM_TIMEOUT) --toplevel $(TOP) --test-module $(TB_MODULE) --test-dir $(TB_DIR) \
	  --build-dir $(BUILD)/sim_gls --results $@ --waves $(WAVES) $(addprefix --sim-arg=,$(GLS_XRUN_ARGS)) \
	  --sources $(BUILD)/final_logic.v $(CELL_VERILOG) $(MACRO_NETLISTS) $(TB_SOURCES)
	$(LOG_CHECK) gls $(BUILD)/sim_gls/xrun_build.log $(BUILD)/sim_gls/xrun_test.log
