#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CCACHE_TEMPDIR=${CCACHE_TEMPDIR:-/tmp/ps01-ccache}
export CCACHE_DIR=${CCACHE_DIR:-/tmp/ps01-ccache-cache}
mkdir -p reports/hardware build waveforms
rm -f build/rtl_verified build/sim_pass build/lint_pass
log="reports/hardware/regression_$(date -u +%Y%m%dT%H%M%SZ)_$$.log"
exec > >(tee "$log" reports/hardware/full_regression.log) 2>&1
trap 'echo "REGRESSION_EXIT=$?"' EXIT
run() { printf '\nCOMMAND:'; printf ' %q' "$@"; printf '\n'; "$@"; }
run python3 -B -m unittest discover -s tests -v
run python3 -B model/gru_hardware.py
run python3 -B model/gru_hardware.py --out build/hardware_max --inputs 16 --hidden 32 --frames 256
run python3 -B model/gru_hardware.py --out build/hardware_stress --inputs 16 --hidden 32 --frames 128 --stress
run env SIM=verilator bash scripts/run_sim.sh
run verilator --binary --timing -Wno-fatal --top-module tb_ema_alert --Mdir build/obj_ema rtl/*.sv tb/tb_ema_alert.sv
run build/obj_ema/Vtb_ema_alert
run verilator --binary --timing -Wno-fatal --top-module tb_voice_stability_top -GINPUTS=16 -GHIDDEN=32 --Mdir build/obj_max rtl/*.sv tb/tb_voice_stability_top.sv
run build/obj_max/Vtb_voice_stability_top +DATA=build/hardware_max +FRAMES=256
run build/obj_max/Vtb_voice_stability_top +DATA=build/hardware_stress +FRAMES=128
run verilator --lint-only --Wall --top-module voice_stability_top rtl/*.sv
run verilator --lint-only --Wall --top-module voice_stability_top -GINPUTS=16 -GHIDDEN=32 rtl/*.sv
run python3 -B model/compare_hardware_formats.py
# Marker is only written after the complete required target regression passes.
touch build/rtl_verified build/lint_pass
