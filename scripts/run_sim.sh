#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build reports waveforms
export CCACHE_TEMPDIR=${CCACHE_TEMPDIR:-/tmp/ps01-ccache}
export CCACHE_DIR=${CCACHE_DIR:-/tmp/ps01-ccache-cache}
rm -f build/rtl_verified build/sim_pass
sim=${SIM:-auto}
if [[ "$sim" == auto ]]; then
  if command -v verilator >/dev/null; then sim=verilator
  elif command -v iverilog >/dev/null && command -v vvp >/dev/null; then sim=iverilog
  elif command -v xrun >/dev/null; then sim=xrun
  else echo "BLOCKED: no Icarus, Verilator or Xcelium simulator" >&2; exit 2; fi
fi
for bench in tb_moving_average tb_gru_cell tb_voice_stability_top; do
  case "$sim" in
    iverilog)
      command -v iverilog >/dev/null; command -v vvp >/dev/null
      iverilog -g2012 -Wall -s "$bench" -o "build/$bench.vvp" rtl/*.sv "tb/$bench.sv" 2>&1 | tee "reports/${bench}_compile.log"
      vvp "build/$bench.vvp" 2>&1 | tee "reports/$bench.log" ;;
    verilator)
      command -v verilator >/dev/null
      verilator --binary --timing --trace -Wno-fatal --top-module "$bench" --Mdir "build/obj_$bench" rtl/*.sv "tb/$bench.sv" 2>&1 | tee "reports/${bench}_compile.log"
      "build/obj_$bench/V$bench" 2>&1 | tee "reports/$bench.log" ;;
    xrun)
      command -v xrun >/dev/null
      xrun -64bit -sv -access +rwc -top "$bench" -xmlibdirname "build/xcelium_$bench" rtl/*.sv "tb/$bench.sv" -l "reports/$bench.log" ;;
    *) echo "Unsupported SIM=$sim" >&2; exit 2 ;;
  esac
  # Require explicit completion in addition to a zero simulator exit status.
  rg '^PASS:' "reports/$bench.log" >/dev/null || { echo "FAIL: missing PASS for $bench"; exit 1; }
done
touch build/sim_pass
