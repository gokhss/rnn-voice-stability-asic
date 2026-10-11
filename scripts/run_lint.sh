#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build reports
rm -f build/rtl_verified build/lint_pass
if command -v verilator >/dev/null; then
  # Warnings remain visible. Errors are fatal; review warning log before signoff.
  verilator --lint-only --Wall -Wno-fatal --top-module voice_stability_top rtl/*.sv 2>&1 | tee reports/lint.log
elif command -v iverilog >/dev/null; then
  echo "Using Icarus syntax/elaboration check; full lint unavailable" | tee reports/lint.log
  iverilog -g2012 -Wall -s voice_stability_top -o build/lint.vvp rtl/*.sv 2>&1 | tee -a reports/lint.log
else
  echo "BLOCKED: lint needs Verilator or Icarus" >&2; exit 2
fi
touch build/lint_pass
