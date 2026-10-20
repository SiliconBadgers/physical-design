# File:        design.mk
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Design config for sb_systolic_tile, the 4x4 int8 systolic MAC array, Track B1. Its four weight memories are sb_sram_256x8 hard macros.
TOP          := sb_systolic_tile
RTL_FILES    := $(addprefix $(DESIGN_DIR)/rtl/,reset_sync.sv pe.sv pe_ctrl.sv readout.sv tile_top.sv)
RTL_INCDIRS  := $(DESIGN_DIR)/rtl
RTL_DEFINES  :=
SDC_FILE     := $(TRACK_DESIGN_DIR)/constraint.sdc

# hard macro: built from designs/sb_sram_256x8 first; a black box for lint (Genus reads its timing model)
MACROS           := sb_sram_256x8
MACRO_VERILOG    := $(TRACK_DESIGN_DIR)/sb_sram_256x8_bb.v
MACRO_SIM_MODELS := $(SB_ROOT)/designs/sb_sram_256x8/rtl/sb_sram_256x8.v

TB_DIR       := $(DESIGN_DIR)/tb
TB_MODULE    := test_tile
TB_SOURCES   :=

# --- place and route ---
CORE_UTILIZATION := 40
ASPECT_RATIO     := 1
# core to die margin (um): room for the power ring
CORE_MARGIN      := 10
PLACE_DENSITY    := 0.60
