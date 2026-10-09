# File:        sky130hd.mk
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: sky130hd platform settings for the Synopsys tools. Cell views come from the SiliconBadgers sky130 PDK repo (synopsys/, with views/ built by make_views.sh); DRC and LVS decks from its open/sky130hd/.

# SiliconBadgers sky130 PDK repo
SB_PDK   ?= $(abspath $(SB_ROOT)/../silicon-badgers-sky130-pdk)
LIBRARY  := sky130_fd_sc_hd
SNPS_DIR := $(SB_PDK)/synopsys
VIEWS    := $(SNPS_DIR)/views
CELLS    := $(SNPS_DIR)/$(LIBRARY)
TECH     := $(SNPS_DIR)/tech
OPEN_DIR := $(SB_PDK)/open/sky130hd

# --- corners: Liberty name, supply (V), temperature (C) ---
CORNERS     := ss tt ff
LIB_NAME_ss := $(LIBRARY)__ss_100C_1v60
LIB_NAME_tt := $(LIBRARY)__tt_025C_1v80
LIB_NAME_ff := $(LIBRARY)__ff_n40C_1v95
VOLT_ss := 1.60
VOLT_tt := 1.80
VOLT_ff := 1.95
TEMP_ss := 100
TEMP_tt := 25
TEMP_ff := -40
# $(call cell_db,<corner>): compiled Liberty of one corner
cell_db = $(VIEWS)/$(LIB_NAME_$(1)).db

# --- views built once by $(SNPS_DIR)/make_views.sh ---
CELL_DBS := $(foreach c,$(CORNERS),$(call cell_db,$(c)))
CELL_NDM := $(VIEWS)/$(LIBRARY).ndm
TLUPLUS  := $(VIEWS)/skywater130.nominal.tluplus
NXTGRD   := $(VIEWS)/skywater130.nominal.nxtgrd

# --- technology and cell files ---
TECH_FILE := $(TECH)/$(LIBRARY).tf
GDS_MAP   := $(TECH)/skywater130_fd_sc_hd.map
TECH_LEF  := $(CELLS)/lef/$(LIBRARY).tlef
CELL_LEF  := $(CELLS)/lef/$(LIBRARY).lef
CELL_GDS  := $(CELLS)/gds/$(LIBRARY).gds

# --- synthesis ---
# cells synthesis must not use: power-gating, probe, clock and delay cells
DONT_USE := $(LIBRARY)__lpflow_* $(LIBRARY)__probe* \
            $(LIBRARY)__clk* $(LIBRARY)__dlygate* $(LIBRARY)__dlymetal*

# --- place and route ---
# cells place and route must not use (clock and delay cells are allowed here)
PNR_DONT_USE := $(LIBRARY)__probe* $(LIBRARY)__lpflow_*
# row site; auto = unithd if the library has it, else unit (the .tf name)
SITE         ?= auto
TAP_CELL     := $(LIBRARY)__tapvpwrvgnd_1
# biggest first
FILL_CELLS   := $(LIBRARY)__fill_8 $(LIBRARY)__fill_4 $(LIBRARY)__fill_2 $(LIBRARY)__fill_1
DIODE_CELL   := $(LIBRARY)__diode_2
# cells the clock tree may use; empty = the tool picks
CTS_BUF_LIST ?= $(LIBRARY)__clkbuf_4 $(LIBRARY)__clkbuf_8 $(LIBRARY)__clkbuf_16
# pin layers: horizontal, vertical
IO_H_LAYER := met3
IO_V_LAYER := met2
MIN_ROUTING_LAYER     := met1
MIN_CLK_ROUTING_LAYER := met3
MAX_ROUTING_LAYER     := met5

# --- layout and signoff (KLayout) ---
KLAYOUT_LYT := $(OPEN_DIR)/sky130hd.lyt
DRC_DECK    := $(OPEN_DIR)/drc/sky130hd.lydrc
LVS_DECK    := $(OPEN_DIR)/lvs/sky130hd.lylvs
CDL_FILE    := $(OPEN_DIR)/cdl/sky130hd.cdl
