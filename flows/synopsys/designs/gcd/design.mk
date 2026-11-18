# File:        design.mk
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: Design config for the ORFS gcd unit (16-bit Euclid GCD), Track B2.
TOP          := gcd
RTL_FILES    := $(DESIGN_DIR)/rtl/gcd.v
RTL_INCDIRS  :=
RTL_DEFINES  :=
SDC_FILE     := $(TRACK_DESIGN_DIR)/constraint.sdc

TB_DIR       := $(DESIGN_DIR)/tb
TB_MODULE    := test_gcd
TB_SOURCES   :=

# --- place and route ---
CORE_UTILIZATION := 40
ASPECT_RATIO     := 1
# core to die margin (um)
CORE_MARGIN      := 2
PLACE_DENSITY    := 0.60
