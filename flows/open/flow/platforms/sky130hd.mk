# File:        sky130hd.mk
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: sky130hd platform settings. All files come from the SiliconBadgers sky130 PDK repo (ORFS platform format).

# SiliconBadgers sky130 PDK repo
SB_PDK       ?= $(SB_ROOT)/../silicon-badgers-sky130-pdk
PLATFORM_DIR := $(SB_PDK)/open/sky130hd

# --- libraries and views (typical corner only) ---
CORNERS  := tt
LIB_tt   := $(PLATFORM_DIR)/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
TECH_LEF := $(PLATFORM_DIR)/lef/sky130_fd_sc_hd.tlef
CELL_LEF := $(PLATFORM_DIR)/lef/sky130_fd_sc_hd_merged.lef
CELL_GDS := $(PLATFORM_DIR)/gds/sky130_fd_sc_hd.gds

# --- synthesis cells ---
TIEHI_CELL := sky130_fd_sc_hd__conb_1
TIEHI_PORT := HI
TIELO_CELL := sky130_fd_sc_hd__conb_1
TIELO_PORT := LO
BUF_CELL   := sky130_fd_sc_hd__buf_4
BUF_IN     := A
BUF_OUT    := X
# cells the flow must not use: power-gating, probe, clock and delay cells
DONT_USE    := sky130_fd_sc_hd__lpflow_* sky130_fd_sc_hd__probe* \
               sky130_fd_sc_hd__clk* sky130_fd_sc_hd__dlygate* sky130_fd_sc_hd__dlymetal*
# latch cells, for the latch check
LATCH_CELLS := sky130_fd_sc_hd__dlx* sky130_fd_sc_hd__dlr*

# SDC helpers: input driver and output load cells
DRIVING_CELL := sky130_fd_sc_hd__buf_2
DRIVING_PIN  := X
LOAD_CELL    := sky130_fd_sc_hd__buf_4
LOAD_PIN     := A

# --- place and route ---
# cells place and route must not use (clock and delay cells are allowed here)
PNR_DONT_USE  := sky130_fd_sc_hd__probe* sky130_fd_sc_hd__lpflow_*
SITE          := unithd
TAP_CELL      := sky130_fd_sc_hd__tapvpwrvgnd_1
FILL_CELLS    := sky130_fd_sc_hd__fill_1 sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_4 sky130_fd_sc_hd__fill_8
# pin layers: horizontal, vertical
IO_H_LAYER    := met3
IO_V_LAYER    := met2
MIN_ROUTING_LAYER     := met1
MIN_CLK_ROUTING_LAYER := met3
MAX_ROUTING_LAYER     := met5
PDN_TCL         := $(PLATFORM_DIR)/pdn.tcl
TAPCELL_TCL     := $(PLATFORM_DIR)/tapcell.tcl
MAKE_TRACKS_TCL := $(PLATFORM_DIR)/make_tracks.tcl
SETRC_TCL       := $(PLATFORM_DIR)/setRC.tcl
FASTROUTE_TCL   := $(PLATFORM_DIR)/fastroute.tcl
RCX_RULES       := $(PLATFORM_DIR)/rcx_patterns.rules
# supply nets and voltage for IR analysis
PWR_NET := VDD
GND_NET := VSS
VDD_V   := 1.8

# --- layout and signoff ---
KLAYOUT_LYT := $(PLATFORM_DIR)/sky130hd.lyt
DRC_DECK    := $(PLATFORM_DIR)/drc/sky130hd.lydrc
LVS_DECK    := $(PLATFORM_DIR)/lvs/sky130hd.lylvs
CDL_FILE    := $(PLATFORM_DIR)/cdl/sky130hd.cdl
