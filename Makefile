SHELL := /bin/bash
include config/parameters.mk
-include config/tech_config.mk
export
.PHONY: help model sim lint test hardware-test generic-synth synth sta pnr gds reports clean
help:
	@echo "model sim lint test synth sta pnr gds reports clean"
	@echo "Configure licensed technology/tool paths in config/tech_config.mk."
model:
	@mkdir -p build reports waveforms gds
	$(PYTHON) model/generate_weights.py
	$(PYTHON) model/gru_reference.py --check
sim:
	$(PYTHON) -B model/gru_hardware.py
	bash scripts/run_sim.sh
lint:
	bash scripts/run_lint.sh
test: hardware-test
hardware-test:
	bash scripts/run_hardware_regression.sh
generic-synth: hardware-test
	bash scripts/run_generic_synthesis.sh
synth: test
	@command -v "$(GENUS)" >/dev/null || { echo "BLOCKED: configure GENUS executable"; exit 2; }
	$(GENUS) -no_gui -files scripts/run_synthesis.tcl
sta:
	@command -v "$(TEMPUS)" >/dev/null || { echo "BLOCKED: configure TEMPUS executable"; exit 2; }
	$(TEMPUS) -no_gui -files scripts/run_sta.tcl
pnr:
	@command -v "$(INNOVUS)" >/dev/null || { echo "BLOCKED: configure INNOVUS executable"; exit 2; }
	$(INNOVUS) -no_gui -files scripts/run_pnr.tcl
gds: pnr
	bash scripts/run_drc_lvs.sh
reports:
	$(PYTHON) scripts/report_qor.py
clean:
	rm -rf build reports waveforms gds
