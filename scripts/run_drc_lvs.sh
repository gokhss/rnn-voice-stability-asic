#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for key in DRC_WRAPPER LVS_WRAPPER DRC_DECK LVS_DECK; do
  value=${!key:-}
  [[ -n "$value" && -f "$value" ]] || { echo "BLOCKED: configure existing $key" >&2; exit 2; }
done
[[ -s gds/voice_stability_top.gds && -s build/voice_stability_top_routed.v ]] || {
  echo "BLOCKED: missing actual routed GDS/netlist" >&2; exit 2;
}
[[ -x "$DRC_WRAPPER" && -x "$LVS_WRAPPER" ]] || { echo "BLOCKED: signoff wrappers must be executable"; exit 2; }
mkdir -p reports
rm -f reports/drc.rpt reports/lvs.rpt build/signoff_complete
"$DRC_WRAPPER" gds/voice_stability_top.gds build/voice_stability_top_routed.v reports
[[ -s reports/drc.rpt ]] || { echo "FAIL: DRC wrapper produced no report"; exit 1; }
"$LVS_WRAPPER" gds/voice_stability_top.gds build/voice_stability_top_routed.v reports
[[ -s reports/lvs.rpt ]] || { echo "FAIL: LVS wrapper produced no report"; exit 1; }
touch build/signoff_complete
echo "Signoff wrappers completed; inspect actual DRC/LVS reports."
