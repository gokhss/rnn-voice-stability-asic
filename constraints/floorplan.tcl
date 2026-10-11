# Sourced by run_pnr.tcl after environment validation; all dimensions in um.
floorPlan -r 1.0 $::env(CORE_UTILIZATION) $::env(CORE_MARGIN) $::env(CORE_MARGIN) $::env(CORE_MARGIN) $::env(CORE_MARGIN)
globalNetConnect $::env(POWER_NET) -type pgpin -pin $::env(PG_PIN_POWER) -inst *
globalNetConnect $::env(GROUND_NET) -type pgpin -pin $::env(PG_PIN_GROUND) -inst *
addRing -nets [list $::env(POWER_NET) $::env(GROUND_NET)] -type core_rings -follow core   -layer [list top $::env(PG_RING_H_LAYER) bottom $::env(PG_RING_H_LAYER) left $::env(PG_RING_V_LAYER) right $::env(PG_RING_V_LAYER)]   -width $::env(PG_WIDTH) -spacing $::env(PG_SPACING) -offset $::env(PG_OFFSET)
addStripe -nets [list $::env(POWER_NET) $::env(GROUND_NET)] -layer $::env(PG_STRIPE_LAYER)   -direction vertical -width $::env(PG_WIDTH) -spacing $::env(PG_SPACING) -set_to_set_distance $::env(PG_PITCH)
sroute -nets [list $::env(POWER_NET) $::env(GROUND_NET)] -connect {blockPin padPin padRing corePin floatingStripe}
set pins [dbGet top.terms.name]
editPin -pin $pins -side LEFT -layer $::env(SIGNAL_BOTTOM_LAYER) -spreadType SIDE
