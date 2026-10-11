# Copy to ignored config/tech_config.mk. Use local paths; do not commit PDK data.
GENUS ?= genus
INNOVUS ?= innovus
TEMPUS ?= tempus
# Liberty and LEF values must be valid Tcl lists (space-separated paths).
LIB_FILES :=
TECH_LEF :=
CELL_LEFS :=
RC_TECH_FILE :=
GDS_MAP :=
# Tcl list of standard-cell GDS files, merged during streamOut.
CELL_GDS :=
POWER_NET := VDD
GROUND_NET := VSS
PG_PIN_POWER := VDD
PG_PIN_GROUND := VSS
PG_RING_H_LAYER :=
PG_RING_V_LAYER :=
PG_STRIPE_LAYER :=
SIGNAL_BOTTOM_LAYER :=
SIGNAL_TOP_LAYER :=
CTS_CELLS :=
CORE_UTILIZATION := 0.45
CORE_MARGIN := 20
# Units below are micrometres; adapt to the PDK's legal power-grid geometry.
PG_WIDTH := 2
PG_SPACING := 2
PG_OFFSET := 2
PG_PITCH := 40
# Executable wrapper paths. Arguments: GDS netlist reports-directory.
# Wrappers must use the given decks, exit nonzero on violations/mismatches,
# and write reports/drc.rpt or reports/lvs.rpt respectively.
DRC_WRAPPER :=
LVS_WRAPPER :=
DRC_DECK :=
LVS_DECK :=
