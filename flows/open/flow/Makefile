# File:        Makefile
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: SiliconBadgers RTL-to-GDS flow on sky130hd: lint, sim, synth, sta, floorplan, place, cts, grt, route, finish, gds, drc, lvs. Run `make help` for usage.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SECONDARY:

# TRACK_DIR: this track's folder (flow, design.mk, constraints, build/); SB_ROOT: the flow's root, flows/ (shared RTL and testbenches)
TRACK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SB_ROOT  := $(abspath $(TRACK_DIR)/..)
FLOW     := $(TRACK_DIR)/flow
SCRIPTS  := $(FLOW)/scripts
DESIGN   ?= gcd

# tools (on PATH by default)
YOSYS    ?= yosys
OPENROAD ?= openroad
KLAYOUT  ?= klayout
# ORFS checkout, for `make compare`
ORFS     ?= $(HOME)/OpenROAD-flow-scripts

# --- synthesis settings ---
SYNTH_FLATTEN ?= 1
SYNTH_RETIME  ?= 0
SYNTH_FSM     ?= 0
SYNTH_ADDER   ?= kogge-stone
SYNTH_OUTBUF  ?= 1
# 1 = give ABC the input driving cell and output load
ABC_CONSTR    ?= 1
# ABC delay target as a fraction of the clock period
ABC_DELAY_FRAC ?= 0.6
# share of the ABC target for (* keep_hierarchy *) modules
ABC_SUBMODULE_DELAY_FRAC ?= 1.0
ABC_SCRIPT    ?=
RTL_FRONTEND  ?= slang
WAVES         ?= 0
# gate-level simulator: icarus (4-state) or verilator (2-state)
GLS_SIM       ?= icarus
# parallel LEC proofs; eqy runs the Yosys installed next to it (its plugin is built for that one)
LEC_JOBS      ?= $(shell nproc 2>/dev/null || echo 4)
EQY           ?= eqy
EQY_YOSYS     ?= $(or $(wildcard $(dir $(shell command -v $(EQY)))yosys),yosys)

PLATFORM_MK := $(FLOW)/platforms/sky130hd.mk
include $(PLATFORM_MK)

# DESIGN_DIR: the shared design in flows/designs (rtl/, tb/); TRACK_DESIGN_DIR: its files in this track (design.mk, SDC, ...)
DESIGN_DIR       := $(SB_ROOT)/designs/$(DESIGN)
TRACK_DESIGN_DIR := $(TRACK_DIR)/designs/$(DESIGN)
ifeq ($(wildcard $(TRACK_DESIGN_DIR)/design.mk),)
  $(error DESIGN=$(DESIGN): no designs/$(DESIGN)/design.mk)
endif
include $(TRACK_DESIGN_DIR)/design.mk

# --- optional design.mk settings ---
SYNTH_DEFINES  ?=
SIM_RTL        ?= icarus
SIM_ARGS       ?=
DESIGN_PARAMS  ?=
MACRO_VERILOG  ?=
MACRO_LIBS     ?=
MACRO_LEFS     ?=
MACRO_GDS      ?=
MACRO_SIM_MODELS ?=
SLANG_HIERARCHY ?= 0
ASYNC_RESET_PORT ?=
CORE_UTILIZATION ?= 40
ASPECT_RATIO     ?= 1
CORE_MARGIN      ?= 2
PLACE_DENSITY    ?= 0.60
IO_CONSTRAINTS   ?=
GPL_TIMING_DRIVEN      ?= 1
GPL_ROUTABILITY_DRIVEN ?= 1
CTS_BUF_LIST     ?=
SKIP_CTS_REPAIR_TIMING ?= 0
# 1: a buffer on every input and output before placement (as ORFS does)
BUFFER_PORTS     ?= 0
# hard macros: designs built first and used as abstracts (design.mk: MACROS := <design> ...)
MACROS        ?=
MACRO_VARIANT ?= base
MACRO_CDL     ?=
macro_abs      = $(TRACK_DIR)/build/$(1)/$(MACRO_VARIANT)/abstract/$(1)
MACRO_LEFS    += $(foreach m,$(MACROS),$(call macro_abs,$(m)).lef)
MACRO_LIBS    += $(foreach m,$(MACROS),$(call macro_abs,$(m)).lib)
MACRO_GDS     += $(foreach m,$(MACROS),$(call macro_abs,$(m)).gds)
MACRO_CDL     += $(foreach m,$(MACROS),$(call macro_abs,$(m)).cdl)
# routed netlists of the macros, for gate-level simulation
MACRO_NETLISTS := $(foreach m,$(MACROS),$(call macro_abs,$(m)).v)
MACRO_FILES   := $(foreach m,$(MACROS),$(addprefix $(call macro_abs,$(m)),.lef .lib .gds .cdl .v))
# keep-out ring for standard cells around each macro, and minimum channel between macros and the core edge (um)
MACRO_HALO    ?= 10
MACRO_CHANNEL ?= 80
export SB_DESIGN_PARAMS := $(DESIGN_PARAMS)
SYNTH_RTL := $(RTL_FILES) $(MACRO_VERILOG)

# run name; each variant keeps its own build directory
VARIANT ?= base
BUILD   ?= $(TRACK_DIR)/build/$(DESIGN)/$(VARIANT)
TIMES   := $(BUILD)/runtimes.txt
TIMED   := $(SCRIPTS)/util/timed.sh $(TIMES)

# clock period from the SDC (ns), and in ps for ABC
CLOCK_PERIOD_NS := $(if $(wildcard $(SDC_FILE)),$(shell tclsh $(SCRIPTS)/util/clock_period.tcl $(SDC_FILE)))
CLOCK_PERIOD_PS := $(if $(CLOCK_PERIOD_NS),$(shell awk 'BEGIN{printf "%d", $(CLOCK_PERIOD_NS)*1000 + 0.5}'))
ABC_DELAY_PS    := $(if $(CLOCK_PERIOD_NS),$(shell awk 'BEGIN{printf "%d", $(CLOCK_PERIOD_NS)*1000*$(ABC_DELAY_FRAC) + 0.5}'))

FLOW_DEPS := $(PLATFORM_MK) $(TRACK_DESIGN_DIR)/design.mk
OR_RUN    := $(OPENROAD) -no_init -no_splash -exit

# --- targets ---
.PHONY: help info all lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls lec-mutation abstract macros compare clean FORCE
# stages run in order (macros are built before synthesis)
.NOTPARALLEL:
FORCE:
help:
	@echo "usage: make <stage> DESIGN=<design> [VARIANT=<name>] [<VARIABLE>=<value> ...]"
	@echo "  stages:  lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls | abstract | all | compare | clean | info"
	@echo "  DESIGN:  $(notdir $(wildcard $(TRACK_DIR)/designs/*))"
	@echo "  compare: run ORFS on the same netlist and SDC and print both flows' numbers per stage"
	@echo "  lec-mutation: LEC must fail on broken netlists"
	@echo "outputs: build/<DESIGN>/<VARIANT>/"

info:
	@echo "DESIGN=$(DESIGN) TOP=$(TOP) SDC=$(SDC_FILE) period=$(CLOCK_PERIOD_NS) ns"
	@echo "PDK=$(PLATFORM_DIR)"
	@echo "BUILD=$(BUILD)"

print-%:
	@echo '$($*)'

all: lint sim synth sta floorplan place cts grt route finish gds drc lvs lec gls

lint:      $(BUILD)/lint.log
sim:       $(if $(TB_MODULE),$(BUILD)/results.xml)
synth:     macros $(BUILD)/netlist.v
sta:       macros $(BUILD)/sta_tt.rpt
floorplan: macros $(BUILD)/floorplan.odb
place:     macros $(BUILD)/place.odb
cts:       macros $(BUILD)/cts.odb
grt:       macros $(BUILD)/grt.odb
route:     macros $(BUILD)/route.odb
finish:    macros $(BUILD)/final.odb
gds:       macros $(BUILD)/final.gds
drc:       macros $(BUILD)/drc_count.txt
lvs:       macros $(BUILD)/lvs.lvsdb
lec:       macros $(BUILD)/lec_synth.log $(BUILD)/lec_route.log
gls:       macros $(if $(TB_MODULE),$(BUILD)/gls_results.xml)
abstract:  $(BUILD)/abstract/$(TOP).lef $(BUILD)/abstract/$(TOP).gds

# build each macro's abstract in its own make: only the PDK and tool paths pass on, not other command-line settings
MACRO_MAKE_VARS := SB_PDK YOSYS OPENROAD KLAYOUT
cmdline_vars     = $(strip $(foreach v,$(.VARIABLES),$(if $(filter command line,$(origin $(v))),$(v))))
macros:
	@$(foreach m,$(MACROS),env -u MAKEFLAGS -u MFLAGS $(addprefix -u ,$(cmdline_vars)) \
	  $(MAKE) --no-print-directory $(if $(findstring n,$(firstword -$(MAKEFLAGS))),-n) -C $(TRACK_DIR) abstract \
	  DESIGN=$(m) VARIANT=$(MACRO_VARIANT) $(foreach v,$(MACRO_MAKE_VARS),$(v)='$($(v))') &&) true
$(MACRO_FILES): ;

clean:
	rm -rf $(BUILD)

$(BUILD):
	mkdir -p $@

# --- lint (Verilator and sb_lint gate, Verible is advisory) ---
LINT_WAIVERS ?= $(wildcard $(TRACK_DESIGN_DIR)/lint_waivers.vlt)
$(BUILD)/lint.log: $(RTL_FILES) $(MACRO_VERILOG) $(LINT_WAIVERS) $(FLOW_DEPS) $(SCRIPTS)/lint/sb_lint.py | $(BUILD)
	@echo "== lint: verilator --lint-only -Wall" | tee $@
	verilator --lint-only -Wall --top-module $(TOP) $(addprefix -I,$(RTL_INCDIRS)) \
	  $(addprefix -D,$(RTL_DEFINES)) $(addprefix -G,$(DESIGN_PARAMS)) $(LINT_WAIVERS) $(RTL_FILES) $(MACRO_VERILOG) 2>&1 | tee -a $@
	@echo "== lint: sb_lint" | tee -a $@
	python3 $(SCRIPTS)/lint/sb_lint.py $(RTL_FILES) 2>&1 | tee -a $@
	@echo "LINT_STATUS: verilator+sb_lint PASS" | tee -a $@

# --- sim (cocotb on the RTL) ---
$(BUILD)/results.xml: $(RTL_FILES) $(MACRO_SIM_MODELS) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) $(FLOW_DEPS) | $(BUILD)
	$(TIMED) sim python3 $(SCRIPTS)/sim/run_cocotb.py --sim $(SIM_RTL) $(addprefix --sim-arg=,$(SIM_ARGS)) \
	  --toplevel $(TOP) --test-module $(TB_MODULE) --test-dir $(TB_DIR) \
	  --build-dir $(BUILD)/sim_rtl --results $@ --waves $(WAVES) \
	  $(addprefix --incdir ,$(RTL_INCDIRS)) $(addprefix --define ,$(RTL_DEFINES)) \
	  $(addprefix --param ,$(DESIGN_PARAMS)) \
	  --sources $(RTL_FILES) $(MACRO_SIM_MODELS) $(TB_SOURCES)

# --- synth ---
# inputs for synth.tcl; the file is replaced only when its content changes
$(BUILD)/synth.env: FORCE | $(BUILD)
	@{ \
	  echo "# Inputs for flow/scripts/yosys/synth.tcl (generated by make)"; \
	  echo "export SB_ROOT='$(SB_ROOT)'"; \
	  echo "export TOP='$(TOP)'"; \
	  echo "export RTL_FILES='$(SYNTH_RTL)'"; \
	  echo "export RTL_INCDIRS='$(RTL_INCDIRS)'"; \
	  echo "export RTL_DEFINES='$(RTL_DEFINES) $(SYNTH_DEFINES)'"; \
	  echo "export RTL_PARAMS='$(DESIGN_PARAMS)'"; \
	  echo "export RTL_FRONTEND='$(RTL_FRONTEND)' SLANG_HIERARCHY='$(SLANG_HIERARCHY)'"; \
	  echo "export LIB_MAP='$(LIB_tt)'"; \
	  echo "export LIB_EXTRA=''"; \
	  echo "export MACRO_LIBS='$(MACRO_LIBS)'"; \
	  echo "export CLOCK_PERIOD_PS='$(CLOCK_PERIOD_PS)' ABC_DELAY_PS='$(ABC_DELAY_PS)'"; \
	  echo "export TIEHI_CELL='$(TIEHI_CELL)' TIEHI_PORT='$(TIEHI_PORT)'"; \
	  echo "export TIELO_CELL='$(TIELO_CELL)' TIELO_PORT='$(TIELO_PORT)'"; \
	  echo "export BUF_CELL='$(BUF_CELL)' BUF_IN='$(BUF_IN)' BUF_OUT='$(BUF_OUT)'"; \
	  echo "export DONT_USE='$(DONT_USE)'"; \
	  echo "export LATCH_CELLS='$(LATCH_CELLS)'"; \
	  echo "export SYNTH_FLATTEN='$(SYNTH_FLATTEN)' SYNTH_RETIME='$(SYNTH_RETIME)' SYNTH_FSM='$(SYNTH_FSM)'"; \
	  echo "export SYNTH_ADDER='$(SYNTH_ADDER)' SYNTH_OUTBUF='$(SYNTH_OUTBUF)'"; \
	  echo "export ABC_SCRIPT='$(ABC_SCRIPT)' ABC_SUBMODULE_DELAY_FRAC='$(ABC_SUBMODULE_DELAY_FRAC)'"; \
	  echo "export ABC_CONSTR_FILE='$(if $(filter 1,$(ABC_CONSTR)),$(BUILD)/abc.constr)'"; \
	  echo "export OUT_DIR='$(BUILD)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

# ABC constraints: input driving cell and output load (4 x LOAD_CELL pin, fF)
$(BUILD)/abc.constr: $(LIB_tt) $(FLOW_DEPS) $(SCRIPTS)/util/liberty_pin_cap.py | $(BUILD)
	@cap=$$(python3 $(SCRIPTS)/util/liberty_pin_cap.py $(LIB_tt) $(LOAD_CELL) $(LOAD_PIN)) && \
	{ echo "set_driving_cell $(DRIVING_CELL)"; \
	  awk -v c=$$cap 'BEGIN { printf "set_load %.2f\n", 4 * c * 1000 }'; } > $@

$(BUILD)/netlist.v: $(BUILD)/synth.env $(SYNTH_RTL) $(MACRO_LIBS) $(SDC_FILE) $(FLOW_DEPS) $(SCRIPTS)/yosys/synth.tcl \
                    $(if $(filter 1,$(ABC_CONSTR)),$(BUILD)/abc.constr)
	@test -n "$(CLOCK_PERIOD_PS)" || { echo "could not read the clock period from $(SDC_FILE)"; exit 1; }
	cd $(BUILD) && source synth.env && \
	  $(TIMED) synth $(YOSYS) -q -l synth.log -c $(SCRIPTS)/yosys/synth.tcl || \
	  { echo "synthesis FAILED -- read $(BUILD)/synth.log"; exit 1; }
	@grep -E 'Chip area|cells$$' $(BUILD)/synth_stat.txt | head -3 || true

# --- sta (pre-layout, OpenSTA inside OpenROAD) ---
$(BUILD)/sta_tt.env: FORCE | $(BUILD)
	@{ \
	  echo "# Inputs for flow/scripts/sta/sta.tcl (generated by make)"; \
	  echo "export SB_ROOT='$(SB_ROOT)'"; \
	  echo "export TOP='$(TOP)' CORNER='tt'"; \
	  echo "export NETLIST='$(BUILD)/netlist.v'"; \
	  echo "export SDC_FILE='$(SDC_FILE)'"; \
	  echo "export LIBS='$(LIB_tt)'"; \
	  echo "export MACRO_LIBS='$(MACRO_LIBS)'"; \
	  echo "export TECH_LEF='$(TECH_LEF)' CELL_LEF='$(CELL_LEF)' MACRO_LEFS='$(MACRO_LEFS)'"; \
	  echo "export DRIVING_CELL='$(DRIVING_CELL)' DRIVING_PIN='$(DRIVING_PIN)'"; \
	  echo "export LOAD_CELL='$(LOAD_CELL)' LOAD_PIN='$(LOAD_PIN)'"; \
	  echo "export CLOCK_PERIOD=''"; \
	  echo "export ASYNC_RESET_PORT='$(ASYNC_RESET_PORT)'"; \
	  echo "export OUT_DIR='$(BUILD)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

$(BUILD)/sta_tt.rpt: $(BUILD)/sta_tt.env $(BUILD)/netlist.v $(SDC_FILE) $(SCRIPTS)/sta/sta.tcl
	cd $(BUILD) && source sta_tt.env && \
	  $(TIMED) sta $(OR_RUN) $(SCRIPTS)/sta/sta.tcl 2>&1 | tee sta_tt.log | grep '^SB:'

# --- place and route (one OpenROAD run per stage) ---
$(BUILD)/pnr.env: FORCE | $(BUILD)
	@{ \
	  echo "# Inputs for flow/scripts/pnr/*.tcl (generated by make)"; \
	  echo "export SCRIPTS='$(SCRIPTS)' OUT_DIR='$(BUILD)'"; \
	  echo "export TOP='$(TOP)' NETLIST='$(BUILD)/netlist.v' SDC_FILE='$(SDC_FILE)'"; \
	  echo "export LIBS='$(LIB_tt)' MACRO_LIBS='$(MACRO_LIBS)'"; \
	  echo "export TECH_LEF='$(TECH_LEF)' CELL_LEF='$(CELL_LEF)' MACRO_LEFS='$(MACRO_LEFS)'"; \
	  echo "export SITE='$(SITE)' TAP_CELL='$(TAP_CELL)' FILL_CELLS='$(FILL_CELLS)'"; \
	  echo "export PNR_DONT_USE='$(PNR_DONT_USE)'"; \
	  echo "export IO_H_LAYER='$(IO_H_LAYER)' IO_V_LAYER='$(IO_V_LAYER)'"; \
	  echo "export MIN_ROUTING_LAYER='$(MIN_ROUTING_LAYER)' MAX_ROUTING_LAYER='$(MAX_ROUTING_LAYER)'"; \
	  echo "export MIN_CLK_ROUTING_LAYER='$(MIN_CLK_ROUTING_LAYER)'"; \
	  echo "export PDN_TCL='$(PDN_TCL)' TAPCELL_TCL='$(TAPCELL_TCL)' MAKE_TRACKS_TCL='$(MAKE_TRACKS_TCL)'"; \
	  echo "export SETRC_TCL='$(SETRC_TCL)' FASTROUTE_TCL='$(FASTROUTE_TCL)' RCX_RULES='$(RCX_RULES)'"; \
	  echo "export CDL_FILE='$(CDL_FILE)' MACRO_CDL='$(MACRO_CDL)'"; \
	  echo "export MACRO_HALO='$(MACRO_HALO)' MACRO_CHANNEL='$(MACRO_CHANNEL)'"; \
	  echo "export PWR_NET='$(PWR_NET)' GND_NET='$(GND_NET)' VDD_V='$(VDD_V)'"; \
	  echo "export CORE_UTILIZATION='$(CORE_UTILIZATION)' ASPECT_RATIO='$(ASPECT_RATIO)' CORE_MARGIN='$(CORE_MARGIN)'"; \
	  echo "export PLACE_DENSITY='$(PLACE_DENSITY)' IO_CONSTRAINTS='$(IO_CONSTRAINTS)' BUFFER_PORTS='$(BUFFER_PORTS)'"; \
	  echo "export GPL_TIMING_DRIVEN='$(GPL_TIMING_DRIVEN)' GPL_ROUTABILITY_DRIVEN='$(GPL_ROUTABILITY_DRIVEN)'"; \
	  echo "export CTS_BUF_LIST='$(CTS_BUF_LIST)' SKIP_CTS_REPAIR_TIMING='$(SKIP_CTS_REPAIR_TIMING)'"; \
	} > $@.tmp
	@cmp -s $@.tmp $@ && rm $@.tmp || mv $@.tmp $@

PNR_DEPS := $(BUILD)/pnr.env $(SDC_FILE) $(SCRIPTS)/pnr/common.tcl
# $(call pnr_stage,<stage>): run scripts/pnr/<stage>.tcl, log and metrics into the build directory
pnr_stage = cd $(BUILD) && source pnr.env && \
  $(TIMED) $(1) $(OR_RUN) -metrics $(BUILD)/$(1).json $(SCRIPTS)/pnr/$(1).tcl > $(1).log 2>&1 || \
  { tail -20 $(1).log; echo "$(1) FAILED -- read $(BUILD)/$(1).log"; exit 1; }

$(BUILD)/floorplan.odb: $(BUILD)/netlist.v $(MACRO_LEFS) $(PNR_DEPS) $(SCRIPTS)/pnr/floorplan.tcl $(IO_CONSTRAINTS)
	$(call pnr_stage,floorplan)
$(BUILD)/place.odb: $(BUILD)/floorplan.odb $(PNR_DEPS) $(SCRIPTS)/pnr/place.tcl
	$(call pnr_stage,place)
$(BUILD)/cts.odb: $(BUILD)/place.odb $(PNR_DEPS) $(SCRIPTS)/pnr/cts.tcl
	$(call pnr_stage,cts)
$(BUILD)/grt.odb: $(BUILD)/cts.odb $(PNR_DEPS) $(SCRIPTS)/pnr/grt.tcl
	$(call pnr_stage,grt)
$(BUILD)/route.odb: $(BUILD)/grt.odb $(PNR_DEPS) $(SCRIPTS)/pnr/route.tcl
	$(call pnr_stage,route)
	@grep -E 'Total number of violations' $(BUILD)/route.log | tail -1 || true
$(BUILD)/final.odb: $(BUILD)/route.odb $(PNR_DEPS) $(SCRIPTS)/pnr/finish.tcl
	$(call pnr_stage,finish)

# abstract of this design for use as a macro: LEF, timing model (tt), LVS and gate netlists; GDS copied on its own
$(BUILD)/abstract/$(TOP).lef: $(BUILD)/final.odb $(SCRIPTS)/pnr/abstract.tcl $(SCRIPTS)/pnr/abstract_antenna.py
	mkdir -p $(BUILD)/abstract
	$(call pnr_stage,abstract)
	python3 $(SCRIPTS)/pnr/abstract_antenna.py --lef $@ --def $(BUILD)/final.def --cell-lefs $(CELL_LEF)
	cp $(BUILD)/final.cdl $(BUILD)/abstract/$(TOP).cdl
	cp $(BUILD)/final.v $(BUILD)/abstract/$(TOP).v
$(BUILD)/abstract/$(TOP).gds: $(BUILD)/final.gds
	mkdir -p $(@D)
	cp $< $@

# --- layout: GDS merge and KLayout DRC ---
$(BUILD)/final.gds: $(BUILD)/final.odb $(MACRO_GDS) $(SCRIPTS)/pnr/gds.py
	cd $(BUILD) && $(TIMED) gds $(KLAYOUT) -zz -rd in_def=final.def -rd lefs="$(TECH_LEF) $(CELL_LEF) $(MACRO_LEFS)" \
	  -rd gds_in="$(CELL_GDS) $(MACRO_GDS)" -rd lyt=$(KLAYOUT_LYT) -rd top=$(TOP) -rd out=final.gds \
	  -r $(SCRIPTS)/pnr/gds.py > gds.log 2>&1 || { tail -5 gds.log; exit 1; }

$(BUILD)/drc_count.txt: $(BUILD)/final.gds
	cd $(BUILD) && $(TIMED) drc $(KLAYOUT) -b -rd in_gds=final.gds -rd report_file=$(BUILD)/drc.lyrdb \
	  -r $(DRC_DECK) > drc.log 2>&1
	@grep -c '<value>' $(BUILD)/drc.lyrdb > $@ || true
	@echo "KLayout DRC violations: $$(cat $@)"

$(BUILD)/lvs.lvsdb: $(BUILD)/final.gds $(CDL_FILE) $(MACRO_CDL)
	cat $(BUILD)/final.cdl $(CDL_FILE) $(MACRO_CDL) > $(BUILD)/final_concat.cdl
	cd $(BUILD) && $(TIMED) lvs $(KLAYOUT) -b -rd in_gds=final.gds -rd cdl_file=$(BUILD)/final_concat.cdl \
	  -rd top_cell=$(TOP) -rd report_file=$(BUILD)/lvs.lvsdb -r $(LVS_DECK) > lvs.log 2>&1 || { tail -5 lvs.log; exit 1; }
	@grep -q 'Netlists match' $(BUILD)/lvs.log && echo "LVS: netlists match" || { echo "LVS FAILED -- read $(BUILD)/lvs.log"; exit 1; }

# --- lec (eqy): RTL vs synthesized netlist, then synthesized vs routed netlist; macros are black boxes ---
$(BUILD)/lec_synth.eqy: $(SCRIPTS)/lec/eqy.template $(SCRIPTS)/lec/make_eqy.py $(BUILD)/netlist.v $(SYNTH_RTL) $(FLOW_DEPS)
	python3 $(SCRIPTS)/lec/make_eqy.py --template $< --out $@ --top $(TOP) \
	  --yosys $(EQY_YOSYS) --frontend $(RTL_FRONTEND) --netlist $(BUILD)/netlist.v --cell-libs $(LIB_tt) --macro-libs $(MACRO_LIBS) \
	  $(if $(filter 1,$(SLANG_HIERARCHY)),--slang-hierarchy) --adder $(SYNTH_ADDER) \
	  --incdirs $(RTL_INCDIRS) --defines $(RTL_DEFINES) $(SYNTH_DEFINES) --params $(DESIGN_PARAMS) \
	  --rtl $(SYNTH_RTL)
$(BUILD)/lec_route.eqy: $(SCRIPTS)/lec/eqy_route.template $(BUILD)/netlist.v $(BUILD)/final.odb $(MACRO_LIBS) $(FLOW_DEPS)
	sed -e 's|@TOP@|$(TOP)|g' -e 's|@GOLD@|$(BUILD)/netlist.v|' -e 's|@GATE@|$(BUILD)/final.v|' \
	  -e 's|@LIBS@|read_liberty -ignore_miss_func $(LIB_tt)$(foreach l,$(MACRO_LIBS),\nread_liberty -lib $(l))|' $< > $@
$(BUILD)/lec_%.log: $(BUILD)/lec_%.eqy
	cd $(BUILD) && rm -rf lec_$* && $(TIMED) lec_$* $(EQY) --yosys $(EQY_YOSYS) -j $(LEC_JOBS) -f -d lec_$* lec_$*.eqy > lec_$*_run.log 2>&1 || \
	  { grep -E 'Failed to prove|DONE' lec_$*_run.log; echo "LEC FAILED -- read $(BUILD)/lec_$*_run.log"; exit 1; }
	@cp $(BUILD)/lec_$*_run.log $@
	@echo "LEC $*: $$(grep -E 'DONE' $@ | tail -1)"

# LEC must still fail on a broken gate netlist (two mutants for each LEC step)
lec-mutation: macros $(BUILD)/lec_synth.eqy $(BUILD)/lec_route.eqy
	python3 $(SCRIPTS)/lec/lec_mutation.py --work $(BUILD)/lec_mutation --cmd "$(EQY) --yosys $(EQY_YOSYS) -j $(LEC_JOBS)" \
	  --check $(BUILD)/lec_synth.eqy $(BUILD)/netlist.v --check $(BUILD)/lec_route.eqy $(BUILD)/final.v

# --- gls: the RTL testbench on the routed netlist (cell models; macros as their routed netlists) ---
$(BUILD)/gls_results.xml: $(BUILD)/final.odb $(CELL_VERILOG) $(MACRO_NETLISTS) $(TB_SOURCES) $(wildcard $(TB_DIR)/*.py) \
                          $(SCRIPTS)/gls/run_gls.sh | $(BUILD)
	GLS_SIM=$(GLS_SIM) $(TIMED) gls $(SCRIPTS)/gls/run_gls.sh $(BUILD) $(BUILD)/final.v $(TOP) $(TB_MODULE) $(TB_DIR) \
	  $(WAVES) "$(GLS_DEFINES)" $(CELL_VERILOG) $(MACRO_NETLISTS) $(TB_SOURCES)

# --- compare with ORFS on the same netlist and SDC ---
compare: $(BUILD)/final.odb
	python3 $(SCRIPTS)/qor/compare_orfs.py --build $(BUILD) --orfs $(ORFS) --pdk $(PLATFORM_DIR) \
	  --top $(TOP) --sdc $(SDC_FILE) --util $(CORE_UTILIZATION) --aspect $(ASPECT_RATIO) \
	  --margin $(CORE_MARGIN) --density $(PLACE_DENSITY) --macro-lefs "$(MACRO_LEFS)" --macro-libs "$(MACRO_LIBS)" \
	  --macro-gds "$(MACRO_GDS)"
