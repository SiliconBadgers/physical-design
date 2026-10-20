# File:        design.mk
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Design config for sb_sram_256x8, the tile's weight memory built as a hard macro. `make abstract DESIGN=sb_sram_256x8` writes its LEF, timing model, GDS and netlist.
TOP          := sb_sram_256x8
RTL_FILES    := $(DESIGN_DIR)/rtl/sb_sram_256x8.v
RTL_INCDIRS  :=
RTL_DEFINES  :=
SDC_FILE     := $(TRACK_DESIGN_DIR)/constraint.sdc

# no testbench of its own: the tile test covers it
TB_MODULE    :=

# --- place and route ---
CORE_UTILIZATION := 50
ASPECT_RATIO     := 1
CORE_MARGIN      := 2
PLACE_DENSITY    := 0.65
# power grid and routing stop at met4 so the tile can route over the macro on met5
PDN_TCL           := $(TRACK_DESIGN_DIR)/pdn.tcl
MAX_ROUTING_LAYER := met4
