# Phase 0 repository audit and recovery

**Current run:** Phase 0 and Phase 1 only, local date 2026-10-11. No model/RTL/testbench/flow implementation is authorized. [problem_statement.md](problem_statement.md) is authoritative; [research_paper_review.md](research_paper_review.md) records source-specific support. [architecture_audit.md](architecture_audit.md) is the preceding detailed source/port audit: its source descriptions remain applicable, but its no-RTL-execution status is historical and superseded by the actual checks below.

## Recovery and user changes

The working project is `rnn-voice-stability-asic/` beneath the supplied workspace. `git status --short` and `git branch --show-current` failed with “not a git repository” at both workspace and project roots. There is no current branch, commit checkpoint or trustworthy tracked/uncommitted classification. This does not imply a clean tree: every supplied file is treated as user-owned. No applicable AGENTS.md was found in project or ancestor locations inspected.

A complete checkpoint was created **before documentation edits**, using a tar archive and per-file SHA-256 manifest; all62 original file members were read back and matched. No destructive operation was necessary or performed. Checkpoint (workspace-relative):

`recovery/phase0-20261010T194104Z`

Archive SHA-256: `632453407c42d605aa7661e03fa26d3986c3529016b9957bc7003746aaf545e5`

It contains repository.tar.gz, manifest.json, CHECKPOINT.md (restore into a new directory, never overwrite user changes), audit_evidence.tar.gz (logs/results), and the final run_manifest.json change inventory. The checkpoint is outside the project so the repository audit does not recursively back up its own archive. Generated simulations were isolated under `/tmp/ps01-phase0-checks-jk8d9_tk`; unchanged source copies and existing fixtures were used. No repository artifact markers or reports were overwritten.

## Inventory and architecture

The starting snapshot has62 files:12 RTL modules,3 Python source models,3 SV benches plus vector/readme,7 flow/report scripts,2 configuration files,2 constraints, prior docs/README/license/CI,3 research PDFs, existing weight/report artifacts and4 Python bytecode files. No trained model/checkpoint, dataset, training script, floating reference, target bit-exact model, cocotb/UVM environment, standalone SVA property suite or functional/code coverage database was found. All files are enumerated below and in the recovery manifest. Source/model/script/fixture hashes were compared with the previous complete audit; existing non-README source files are unchanged. The three new papers and previous target documents were reviewed in this run.

The actual implementation defaults to I=8,H=8, not the H=16 Make variable. A captured packed frame drives z then r then candidate dot products through a shared matrix MAC. Candidate reset products are computed outside the MAC; blend uses additional multiply expressions. Gates/hidden state use signed16 Q12, weights/biases also signed16 Q12, and the accumulator is40 bits. Each next-state neuron is staged, then the vector commits atomically. Score is a combinational mean-state projection and sigmoid; pending/score_valid delays completion, and average_valid follows. Circular running average divides by variable valid count. Alert is initialized&&average<threshold. Enable blocks new admission; reset clears state and aborts work. No call flush, learned head, hysteresis, CSR, loader or IRQ exists.

The prior proposed 8/16 architecture is aligned with most PS-01 requirements but remained unimplemented. Research review now explicitly pins biases, gate polarity, matrix orientation and source provenance. The older “required 50MHz” wording is not supported by PS-01;10MHz remains a candidate engineering clock. Existing report files are old snapshots, not updated run evidence. Interface “window/averaging configuration” is implemented by proposed EMA_SHIFT; it is not claimed to be an exact finite-window length.

## Reuse classification and suspected defects

| Component | Classification based on current evidence | Reuse/required change |
|---|---|---|
| feature_buffer, hidden_state_reg | reusable basic capture/atomic persistence behavior; prototype test coverage only | retain concept; add legal dimensions, flush, target integration |
| gru_controller and reset-before dependency structure | reusable scheduling concept; incomplete for new shared auxiliary/head work | counters, memory latency and full operation schedule must change later |
| gru_cell | old arithmetic passes existing Verilator bench; incompatible with target precision/dimensions/resource count | preserve convention, rebuild target datapath under Phase6/7 approval |
| mac_unit / qround | tested ties/saturation in old16×16 Q12 contract; not target16×8 F19 contract | reuse rounding principle; revise ports/scaling/explicit widths later |
| sigmoid_lut / tanh_lut | existing exhaustive RTL and Python checks pass for old PWL | candidate ROM replacement requires independent target error tests; do not reuse old error numbers as target results |
| weight_rom / generate_weights / weights.tsv | deterministic and mutually consistent, **untrained**, incompatible with actual INT8 storage | old integer codes cannot simply be cast; Phase4 exports and Phase6 loader replace design role |
| stability_score | bounded prototype output but not learned/calibrated | learned shared projection and score holding register missing |
| moving_average | existing Icarus directed bench passes; function conflicts with no-divider target | replace with exact shift EMA in authorized RTL phase; preserve old bench until replacement tested |
| alert_controller | current strict comparison matches old tests; incomplete against hysteresis/IRQ requirements | add state/threshold pair/events later |
| Python oracle and128-vector fixture | reusable verification ideas and independent checks for old design only | preserve; new floating reference is Phase2, integer reference Phase5, target vectors later |
| SV benches | useful reset/continuity/arithmetic/startup/backpressure test cases; incomplete system coverage | old benches do not prove AXI compliance, flush, new controls, long-stream or target precision |
| Cadence scripts/SDC/floorplan | unvalidated templates | library, tool dialect, clock/ports, MMMC/activity/physical setup must be validated in Phases9/10 |

Newly observed **portability defect:** Icarus11 rejects weight_rom.sv line3 `input integer neuron,term` as input/reg declarations in this design. Cell/top cannot elaborate with that tool; Verilator accepts and passes existing checks. Record the tool-specific failure without claiming an arithmetic bug from it. Seven top-level Verilator lint WIDTHEXPAND warnings identify implicit-width dependencies in sigmoid_lut, stability_score, moving_average and gru_cell; a zero exit with -Wno-fatal is not clean lint. Top TB changes input data while valid remains high under busy, so it is not a compliant AXI producer example. It prints442 score cycles but lacks a target<1ms assertion. Export and fixtures hard-code8 neurons despite config HIDDEN16. Test/verification marker files are not source-hashed and can go stale. PnR is nominal-corner template and power activity is not supplied.

## Checks actually executed in this run

| Check | Actual result | Scope/limitation |
|---|---|---|
| Git status/branch at both roots | unavailable, no repository metadata | no clean-tree or branch claim |
| Snapshot62 files + archive-member hash comparison | PASS | full recoverability before edits |
| Tool versions and package discovery | completed; details below | discovery is not license/PDK validation |
| Existing Python gru_reference.checks(), imported with -B | PASS | old arithmetic, persistence, mean startup; no target code generated |
| Existing128 stored vectors versus current integer model | PASS all128 | existing untrained8/8 model only |
| Existing weight artifact comparison |408 rows match;384 weights range−255…254,197 raw codes outside signed8 | no new weights; Q12 real range differs from code range |
| Icarus tb_moving_average compile/run | PASS, exit0 and PASS marker | old circular mean, not future EMA |
| Icarus tb_gru_cell and tb_voice_stability_top compilation | FAIL, exit2 each | weight_rom integer input-port elaboration; no simulations on these Icarus builds |
| Verilator top lint --lint-only --Wall -Wno-fatal | exit0, seven width-expansion warnings | warnings retained for review; not warning-free pass |
| Initial Verilator cell/top binary builds | blocked, exit2 | ccache attempted read-only /run/user/1000/ccache-tmp |
| Approved outside-sandbox Verilator retries, unchanged temp source | both compile/run PASS, exit0 and explicit PASS markers | no RTL/testbench edits; existing cell and128-frame top tests only |
| Existing top score latency |442 simulated cycles at20ns clock =8.84µs | prototype8/8 score_valid endpoint, not target frame_done or ASIC timing |
| Paper review | all3 local PDFs read; critical equation pages visually checked | QUANT PDF xref warning recorded, original preserved |
| Documentation links/IDs/schedule/allowed-change integrity | final check recorded in architecture_review.md | not a model or RTL test |

Reproduced old PWL maximum errors over65536 inputs: sigmoid0.01807698997125361, tanh0.03614531386627384. Cell bench compares all128 hidden vectors, exercises MAC ties/saturation and exhaustive activations. Top bench exercises128 scores/states/means, reset abort, disabled admission, stalls and strict threshold equality/crossing. Mean bench covers startup, wrapping, reconfiguration and invalid cycles. No one-hour equivalent, target formats/dimensions, target LUT, QAT, quality accuracy, synthesis, STA, power, PnR or signoff test was run. No new inference/quantization code or new tests were implemented.

Reproduction commands were issued in the isolated directory using existing files: `iverilog -g2012 -Wall -s BENCH -o build/BENCH rtl/*.sv tb/BENCH.sv`, then `vvp build/BENCH`; `verilator --lint-only --Wall -Wno-fatal --top-module voice_stability_top rtl/*.sv`; and `verilator --binary --timing --trace -Wno-fatal --top-module BENCH --Mdir obj_BENCH rtl/*.sv tb/BENCH.sv`, then `obj_BENCH/VBENCH`. Exact logs, including initial failures, are in audit_evidence.tar.gz. These are baseline diagnostic runs, not authorization for Phase8.

## Tools, dependencies, technology

* Python3.10.12, GNU Make4.3, Icarus11.0/vvp, Verilator5.038, Yosys0.9, pdftotext/pdfinfo are discoverable. Versions were queried for Python/Make/Icarus/Verilator/Yosys; PDF extraction/rendering succeeded with the noted QUANT warning.
* Python package discovery finds NumPy. Torch, TensorFlow, cocotb and pytest are not discoverable in this interpreter; no packages installed. Phase2 may use NumPy and standard-library unittest after approval.
* No xrun,genus,innovus,tempus on PATH; no configured tech_config.mk or Liberty/LEF/PDK artifacts in this project. Tools/libraries elsewhere and licenses are unconfirmed, not presumed globally absent. No Cadence license checkout or flow was attempted.

## Risks, blockers and future destructive work

Current blockers to target signoff: absent data/labels/normalization, untrained coefficients, no QAT/floating target/integer target, incomplete RTL features, only limited prototype tests, absent one-hour/corner coverage and unqualified PDK/tools. Fixed F7 ranges, small model capacity, score calibration, LUT error/ROM area and actual power require experiments. Integration must confirm packed stream width and local bus bridge. No research paper supplies missing telecom validation or ASIC power.

No deletion is needed now. Future replacements may retire Q12 synthetic weight ROM/exporter, mean-head logic, variable-divider mean, obsolete fixtures/benches and stale documentation. Preserve them until replacements exist and pass, use a checkpoint, and perform cleanup only in separately authorized **Phase11**. Do not auto-run make model/test/synth during these documentation phases: make dependencies regenerate design artifacts. Next requested approval is **Phase2 only**, not any of that replacement work.

## Full starting file inventory

Every file below is preserved by the checkpoint. Detailed RTL ports/dependencies remain in the prior architecture_audit.md; this listing closes generated/research/document coverage without duplicating that large table.

| Starting file | Class |
|---|---|
| `.github/workflows/rtl-ci.yml` | repository metadata/build/overview |
| `.gitignore` | repository metadata/build/overview |
| `1406.1078v3.pdf` | local research paper |
| `Effective_Quantization_Approaches_for_Recurrent_Neural_Networks.pdf` | local research paper |
| `LICENSE` | repository metadata/build/overview |
| `Makefile` | repository metadata/build/overview |
| `README.md` | repository metadata/build/overview |
| `Towards_the_Extension_of_FPG-AI_Toolflow_to_RNN_Deployment_on_FPGAs_for_On-board_Satellite_Applications.pdf` | local research paper |
| `build/weights.tsv` | existing generated artifact/report |
| `config/parameters.mk` | configuration/template |
| `config/tech_config.example.mk` | configuration/template |
| `constraints/floorplan.tcl` | timing/physical constraint |
| `constraints/top.sdc` | timing/physical constraint |
| `docs/architecture.md` | requirements/architecture/verification documentation |
| `docs/architecture_audit.md` | requirements/architecture/verification documentation |
| `docs/architecture_decisions.md` | requirements/architecture/verification documentation |
| `docs/architecture_migration.md` | requirements/architecture/verification documentation |
| `docs/architecture_review.md` | requirements/architecture/verification documentation |
| `docs/datapath_and_scheduling.md` | requirements/architecture/verification documentation |
| `docs/final_architecture.md` | requirements/architecture/verification documentation |
| `docs/gru_mathematics.md` | requirements/architecture/verification documentation |
| `docs/implementation_roadmap.md` | requirements/architecture/verification documentation |
| `docs/interface_specification.md` | requirements/architecture/verification documentation |
| `docs/numerical_specification.md` | requirements/architecture/verification documentation |
| `docs/problem_statement.md` | requirements/architecture/verification documentation |
| `docs/requirements_traceability.csv` | requirements/architecture/verification documentation |
| `docs/rtl_to_gds_flow.md` | requirements/architecture/verification documentation |
| `docs/verification_plan.md` | requirements/architecture/verification documentation |
| `model/__pycache__/generate_weights.cpython-36.pyc` | derived historical bytecode |
| `model/__pycache__/gru_reference.cpython-36.pyc` | derived historical bytecode |
| `model/__pycache__/quantize.cpython-36.pyc` | derived historical bytecode |
| `model/generate_weights.py` | prototype model/quantization/generator |
| `model/gru_reference.py` | prototype model/quantization/generator |
| `model/quantize.py` | prototype model/quantization/generator |
| `model/requirements.txt` | repository metadata/build/overview |
| `reports/model.json` | existing generated artifact/report |
| `reports/qor.json` | existing generated artifact/report |
| `rtl/alert_controller.sv` | RTL source |
| `rtl/feature_buffer.sv` | RTL source |
| `rtl/gru_cell.sv` | RTL source |
| `rtl/gru_controller.sv` | RTL source |
| `rtl/hidden_state_reg.sv` | RTL source |
| `rtl/mac_unit.sv` | RTL source |
| `rtl/moving_average.sv` | RTL source |
| `rtl/sigmoid_lut.sv` | RTL source |
| `rtl/stability_score.sv` | RTL source |
| `rtl/tanh_lut.sv` | RTL source |
| `rtl/voice_stability_top.sv` | RTL source |
| `rtl/weight_rom.sv` | RTL source |
| `scripts/__pycache__/report_qor.cpython-36.pyc` | derived historical bytecode |
| `scripts/report_qor.py` | flow/report script |
| `scripts/run_drc_lvs.sh` | flow/report script |
| `scripts/run_lint.sh` | flow/report script |
| `scripts/run_pnr.tcl` | flow/report script |
| `scripts/run_sim.sh` | flow/report script |
| `scripts/run_sta.tcl` | flow/report script |
| `scripts/run_synthesis.tcl` | flow/report script |
| `tb/README.md` | existing bench/vector/test documentation |
| `tb/tb_gru_cell.sv` | existing bench/vector/test documentation |
| `tb/tb_moving_average.sv` | existing bench/vector/test documentation |
| `tb/tb_voice_stability_top.sv` | existing bench/vector/test documentation |
| `tb/test_vectors.mem` | existing bench/vector/test documentation |
