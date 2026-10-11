TOP := voice_stability_top
CLOCK_PERIOD_NS := 100
INPUTS := 8
HIDDEN := 16
MAX_WINDOW := 16
# Architecture target: 8 input features, 16 hidden units, INT8 weights,
# INT16 activations, shared MAC, divider-free EMA and explicit state flush.
# Target RTL defaults to HIDDEN=16. scripts/run_hardware_regression.sh also tests 16/32.
PYTHON ?= python3
SIM ?= auto
GENUS ?= genus
INNOVUS ?= innovus
TEMPUS ?= tempus
