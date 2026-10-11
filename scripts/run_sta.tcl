# Cadence Tempus; reports are not generated unless all prerequisites exist.
foreach v {LIB_FILES} {
  if {![info exists ::env($v)] || $::env($v) eq ""} {error "BLOCKED: set $v"}
}
foreach f $::env(LIB_FILES) {if {![file isfile $f]} {error "BLOCKED: missing Liberty"}}
set netlist build/voice_stability_top_mapped.v
set sdc build/voice_stability_top_mapped.sdc
if {[file isfile build/voice_stability_top_routed.v]} {set netlist build/voice_stability_top_routed.v}
foreach f [list $netlist $sdc] {if {![file isfile $f]} {error "BLOCKED: synthesize first"}}
file mkdir reports
read_lib $::env(LIB_FILES)
read_verilog $netlist
set_top_module voice_stability_top
read_sdc $sdc
if {[file isfile build/voice_stability_top.spef]} {read_spef build/voice_stability_top.spef}
check_timing > reports/sta_check.rpt
report_timing -late -max_paths 20 > reports/sta_setup.rpt
report_timing -early -max_paths 20 > reports/sta_hold.rpt
report_constraint -all_violators > reports/sta_violations.rpt
report_analysis_summary > reports/sta_summary.rpt
exit
