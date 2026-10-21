# File:        sky130_scl_9T.mk
# Author:      Isaac Hagedorn
# Date:        2026-10-11
# Description: sky130_scl_9T platform settings. All files come from the cadence/ folder of the SiliconBadgers sky130 PDK repo.

# SiliconBadgers sky130 PDK repo; default: its clone in the physical-design repo root, next to flows/
SB_PDK       ?= $(SB_ROOT)/../silicon-badgers-sky130-pdk
PLATFORM_DIR := $(SB_PDK)/cadence
SCL          := $(PLATFORM_DIR)/sky130_scl_9T
SCL_PHY      := $(PLATFORM_DIR)/sky130_scl_9T_tech

# --- libraries per corner: <process>_<voltage>_<temperature> ---
CORNERS  := ss tt ff
LIB_ss   := $(SCL)/lib/sky130_ss_1.62_125_nldm.lib.gz
LIB_tt   := $(SCL)/lib/sky130_tt_1.8_25_nldm.lib.gz
LIB_ff   := $(SCL)/lib/sky130_ff_1.98_0_nldm.lib.gz
# tie cells TIEHI/TIELO: one typical corner, used at every corner
LIB_EXTRA := $(SCL_PHY)/lib/sky130_scl_9T_phyCells.lib
TECH_LEF  := $(SCL_PHY)/lef/sky130_scl_9T.tlef
CELL_LEF  := $(SCL)/lef/sky130_scl_9T.lef $(SCL_PHY)/lef/sky130_scl_9T_phyCells.lef
CELL_GDS  := $(SCL)/gds/sky130_scl_9T.gds $(SCL_PHY)/gds/sky130_scl_9T_phyCells.gds
CELL_CDL  := $(SCL)/cdl/sky130_scl_9T.cdl $(SCL_PHY)/cdl/sky130_scl_9T_phyCells.cdl
# Innovus layer -> GDS layer
STREAM_MAP := $(SCL)/gds/sky130_stream.mapFile
# Quantus extraction rules, and LEF layer -> Quantus layer names
QRC_TECH      := $(PLATFORM_DIR)/tech/qrcTechFile
QRC_LAYER_MAP := $(FLOW)/platforms/sky130_scl_9T_qrc.map

# --- synthesis cells ---
TIEHI_CELL := TIEHI
TIELO_CELL := TIELO
# cells synthesis must not use: clock, delay, clock-gate, tri-state and scan cells
DONT_USE    := CLK* DLY* ICG* TBUF* SDFF*
# latch cells, for the latch check
LATCH_CELLS := TLAT*

# --- place and route ---
SITE        := CoreSite
FILL_CELLS  := FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1
# fillers with a decoupling capacitor (they have devices, so LVS sees them)
DECAP_CELLS := FILL_DECAP16 FILL_DECAP8
# antenna diode the router inserts where layer changes cannot fix an antenna violation
ANTENNA_CELL := ANTENNA
# cells with no logic (fillers, decaps, antenna diode): left out of final_logic.v, the logic netlist
PHYSICAL_CELLS := $(FILL_CELLS) $(DECAP_CELLS) $(ANTENNA_CELL)
MIN_ROUTING_LAYER     := met1
MAX_ROUTING_LAYER     := met5
# clock nets route on these layers
MIN_CLK_ROUTING_LAYER := met3
MAX_CLK_ROUTING_LAYER := met4
# hard macros route up to this layer; their power pins are straps on it, under the met5 straps of the design that uses them
MACRO_TOP_LAYER := met4
# macro placement grid (um): the row height, a multiple of the met1-met4 track pitches
MACRO_GRID      := 4.14
# supply nets and voltage for IR analysis
PWR_NET := VDD
GND_NET := VSS
VDD_V   := 1.8

# --- gate-level simulation ---
# cell models (zero delay, no defines needed), and the tie cells, which have no model in the PDK
CELL_VERILOG := $(SCL)/verilog/sky130_scl_9T.v $(FLOW)/platforms/sky130_scl_9T_tiecells.v

# --- signoff (Pegasus decks) ---
DRC_DECK := $(PLATFORM_DIR)/tech/pegasus/drc/sky130_rev_0.0_2.12.drc.pvl
LVS_DECK := $(PLATFORM_DIR)/tech/pegasus/lvs/sky130.lvs.v0.0_1.1.pvl
