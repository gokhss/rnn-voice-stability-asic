# Cadence Genus Common UI; validate dialect against your licensed release.
proc require_file {path} {
  if {![file isfile $path]} {error "BLOCKED: missing file $path"}
}
if {![info exists ::env(LIB_FILES)] || $::env(LIB_FILES) eq ""} {error "BLOCKED: set LIB_FILES"}
foreach f $::env(LIB_FILES) {require_file $f}
require_file build/rtl_verified
require_file build/sim_pass
require_file build/lint_pass
file mkdir build reports
set_db library $::env(LIB_FILES)
read_hdl -sv [glob rtl/*.sv]
elaborate voice_stability_top
read_sdc constraints/top.sdc
check_design -unresolved > reports/synth_check.rpt
syn_generic
syn_map
syn_opt
check_design -all > reports/synth_connectivity.rpt
report_timing > reports/synth_timing.rpt
report_area > reports/synth_area.rpt
report_gates > reports/synth_cells.rpt
report_power > reports/synth_power.rpt
write_hdl > build/voice_stability_top_mapped.v
write_sdc > build/voice_stability_top_mapped.sdc
write_db build/synthesis.db
# Power uses tool-default activity unless an actual measured SAIF is configured.
exit
