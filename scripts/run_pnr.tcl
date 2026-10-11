# Cadence Innovus legacy UI. Validate with the installed tool/PDK release.
foreach v {LIB_FILES TECH_LEF CELL_LEFS RC_TECH_FILE GDS_MAP CELL_GDS POWER_NET GROUND_NET PG_PIN_POWER PG_PIN_GROUND PG_RING_H_LAYER PG_RING_V_LAYER PG_STRIPE_LAYER SIGNAL_BOTTOM_LAYER SIGNAL_TOP_LAYER CTS_CELLS CORE_UTILIZATION CORE_MARGIN PG_WIDTH PG_SPACING PG_OFFSET PG_PITCH} {
  if {![info exists ::env($v)] || $::env($v) eq ""} {error "BLOCKED: configure $v"}
}
foreach f [concat $::env(LIB_FILES) [list $::env(TECH_LEF)] $::env(CELL_LEFS) [list $::env(RC_TECH_FILE) $::env(GDS_MAP)] $::env(CELL_GDS) {build/voice_stability_top_mapped.v build/voice_stability_top_mapped.sdc build/rtl_verified}] {
  if {![file isfile $f]} {error "BLOCKED: missing implementation prerequisite $f"}
}
file mkdir build reports gds
set m [open build/mmmc.tcl w]
puts $m [list create_library_set -name nominal_lib -timing $::env(LIB_FILES)]
puts $m [list create_rc_corner -name nominal_rc -qx_tech_file $::env(RC_TECH_FILE)]
puts $m {create_delay_corner -name nominal_delay -library_set nominal_lib -rc_corner nominal_rc}
puts $m {create_constraint_mode -name functional -sdc_files {build/voice_stability_top_mapped.sdc}}
puts $m {create_analysis_view -name nominal -constraint_mode functional -delay_corner nominal_delay}
puts $m {set_analysis_view -setup {nominal} -hold {nominal}}
close $m
set init_top_cell voice_stability_top
set init_verilog build/voice_stability_top_mapped.v
set init_lef_file [concat [list $::env(TECH_LEF)] $::env(CELL_LEFS)]
set init_mmmc_file build/mmmc.tcl
set init_pwr_net $::env(POWER_NET)
set init_gnd_net $::env(GROUND_NET)
init_design
source constraints/floorplan.tcl
setNanoRouteMode -routeBottomRoutingLayer $::env(SIGNAL_BOTTOM_LAYER)
setNanoRouteMode -routeTopRoutingLayer $::env(SIGNAL_TOP_LAYER)
place_opt_design
checkPlace > reports/placement_check.rpt
reportCongestion > reports/congestion.rpt
timeDesign -preCTS -outDir reports/prects
set_ccopt_property buffer_cells $::env(CTS_CELLS)
create_ccopt_clock_tree_spec -file build/ccopt.spec
ccopt_design
timeDesign -postCTS -outDir reports/postcts
report_ccopt_clock_trees > reports/clock_trees.rpt
report_ccopt_skew_groups > reports/clock_skew.rpt
routeDesign
optDesign -postRoute
optDesign -postRoute -hold
timeDesign -postRoute -outDir reports/postroute
timeDesign -postRoute -hold -outDir reports/postroute_hold
verify_drc -report reports/route_drc.rpt
verifyConnectivity -report reports/connectivity.rpt
extractRC
rcOut -spef build/voice_stability_top.spef
report_power > reports/postroute_power.rpt
summaryReport -outfile reports/pnr_summary.rpt
saveNetlist build/voice_stability_top_routed.v
saveDesign build/voice_stability_top.enc
streamOut gds/voice_stability_top.gds -mapFile $::env(GDS_MAP) -libName DesignLib   -merge $::env(CELL_GDS) -units 1000 -mode ALL
# Nominal corner only: supply PDK-qualified multi-corner views for signoff.
exit
