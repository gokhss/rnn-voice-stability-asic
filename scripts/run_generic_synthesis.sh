#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/hardware build
# Generic Boolean mapping only: not technology area, STA or power.
yosys -Q -T -p 'read_verilog -sv rtl/*.sv; hierarchy -check -top voice_stability_top; proc; opt; memory_dff; memory_collect; stat; write_json build/hardware_rtlil.json; synth -top voice_stability_top; check -assert; stat; write_json build/hardware_generic.json' > reports/hardware/yosys.log 2>&1
