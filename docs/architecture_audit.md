# Complete repository architecture audit

Audit date 2026-10-11. Project root is `rnn-voice-stability-asic/` inside the supplied workspace. All 49 existing files were inventoried; all human-readable source/configuration/documentation/report files were read, all stored vector/weight rows were checked. Four Python bytecode cache files are derived non-authoritative binaries (read as bytes for inventory hash, not used as design evidence). No AGENTS.md applies within the project. This supplied tree has no usable Git metadata at the workspace root; historical “tracked” counts cannot be substantiated. Only the ten requested docs and necessary README links/corrections are changed.

## Authority and discrepancies

Primary authority is [docs/problem_statement.md](problem_statement.md). It specifically requires AXI-Stream, quantization-aware training, a register map including weight loading, idle clock gating, MOS/PESQ-derived score correlation above a declared threshold, and cocotb or UVM comparison. The user's 22 requirements are preserved verbatim in the matrix; P01…P05 preserve these additional source obligations. No requirement has been silently dropped. The older architecture.md is a revised target, not implementation evidence: it says “required 50 MHz example clock” although the problem supplies no required frequency. Here 10 MHz is a justified architecture recommendation. It asks for at least40-bit accumulation; this proposal retains40 with a proof. It allows preloaded ROM, but runtime loading is chosen to satisfy the more specific problem. Its completion checklist mixes architecture and eventual verification: this review finalizes a proposal, not verified silicon. README hardware tables mix target16-hidden/INT8 with actual8-hidden/Q12; code governs the audit. config/parameters.mk HIDDEN=16 is not forwarded to elaboration by scripts and changes no RTL default.

## Evidence ledger — actual versus unexecuted

Read-only Python3.10.12 execution using `python3 -B` imported the existing model without its generating main routine. `gru_reference.checks()` passed its integer rounding/saturation, average and state-persistence assertions. Exhaustive existing sigmoid max error=0.01807698997125361; tanh=0.03614531386627384. All 128 existing80-hex-character vector rows matched existing model state/score/mean/alert. All 408 coefficient TSV rows matched generator equations:384 weights plus24 biases; weight range−255…254,197 outside signed 8-bit. This is consistency evidence for the untrained prototype, not independent quality validation or RTL equivalence.

Tool discovery finds /usr/bin/iverilog, /usr/bin/vvp, /usr/local/bin/verilator and /usr/bin/yosys; no xrun, genus, innovus or tempus on PATH. Presence does not prove working installation or license. Existing reports/model.json agrees with reproduced errors. reports/qor.json says every RTL/implementation stage NOT RUN / BLOCKED, all physical metrics NOT MEASURED, and contains no evidence paths. No simulator, lint, synthesis, STA, PnR, power or signoff workflow was run during this architecture-only audit. The historical claim that no simulator is available is stale; historical execution remains unestablished. No private tech_config.mk is supplied. Libraries elsewhere or licenses were not assumed absent merely because executables were not on PATH.

## RTL inventory (actual ports and parameters)

All filenames below are under rtl/. Ports listed collectively retain exact source names; clocks/reset are single-bit synchronous active-low rst_n.

| Module | Parameters | Inputs → outputs | Responsibilities/dependencies |
|---|---|---|---|
| voice_stability_top | INPUTS8,HIDDEN8,MAX_WINDOW16,derived WIN_W | clk,rst_n,enable,frame_valid,features[16I],threshold[16],window_length[WIN_W] → frame_ready,stability_score_out[16],running_average[16],score_valid,average_valid,degradation_alert,busy | instantiates feature_buffer,gru_cell,stability_score,moving_average,alert_controller |
| feature_buffer | INPUTS8 | clk,rst_n,capture,features[16I] → buffered[16I] | latch whole frame on capture |
| gru_cell | INPUTS8,HIDDEN8 | clk,rst_n,start,features[16I] → busy,done,hidden_state[16H] | z/r/n scratch, reset and blend multiplies; instantiates controller,weight_rom,mac,sigmoid,tanh,hidden bank |
| gru_controller | INPUTS8,HIDDEN8 | clk,rst_n,start → busy,clear,accumulate,finish,commit,phase[2],neuron(integer),term(integer) | nested gate/neuron/term FSM |
| weight_rom | INPUTS8,HIDDEN8 | gate[2],neuron(integer),term(integer) → signed 16-bit weight,bias | constant generated3×H×(I+H) Q12 matrix,3H biases |
| mac_unit | ACC_W40 | clk,rst_n,clear,accumulate,signed 16-bit a,b,bias → signed 16-bit result | signed 32-bit product,40-bit acc,bias*4096,round shift12,saturate |
| sigmoid_lut | none | signed 16-bit x → signed 16-bit y | combinational9-knot PWL,integer interpolation multiply/constant divisions |
| tanh_lut | none | signed 16-bit x → signed 16-bit y | widened2*x,clip,instantiates another sigmoid,2*sigmoid−4096 |
| hidden_state_reg | HIDDEN8 | clk,rst_n,commit,next_state[16H] → state[16H] | atomic vector register, no flush |
| stability_score | HIDDEN8 | hidden_state[16H] → score[16] | combinational sum and constant mean coefficient; another sigmoid |
| moving_average | MAX_WINDOW16,derived WIN_W | clk,rst_n,valid,score[16],window_length[WIN_W] → average[16],average_valid,initialized | history ring/running sum/variable divide; reconfiguration clears |
| alert_controller | none | initialized,average[16],threshold[16] → alert | combinational strict comparison, no clock/state/hysteresis |

## Complete non-RTL inventory

| Files | Actual content and limitations |
|---|---|
| README.md; LICENSE; .gitignore | mixed current/target overview and historical reports; MIT terms; excludes artifacts/local technology/cache |
| docs/problem_statement.md | primary requirements |
| docs/architecture.md; architecture_migration.md | corrected aspirational target and unchecked migration checklist |
| docs/gru_mathematics.md | describes current Q12 reset-before, mean head, circular average and strict threshold |
| docs/rtl_to_gds_flow.md | unexecuted Cadence flow guide; historical environment statements |
| model/quantize.py | Q12 saturate, nearest ties-away, multiply and float quantization; no INT8 exporter |
| model/generate_weights.py | deterministic untrained hash, hard-coded8-hidden/16-term TSV writer |
| model/gru_reference.py | integer GRU and average,128-frame fixture generation, arithmetic/activation checks; no training or floating network |
| model/requirements.txt | standard library Python only |
| model/__pycache__/{gru_reference,quantize,generate_weights}.cpython-36.pyc; scripts/__pycache__/report_qor.cpython-36.pyc | four derived historical bytecode artifacts, not source authority |
| tb/tb_gru_cell.sv |128 hidden-vector comparisons,4 MAC probes,exhaustive activation equality against copied PWL formula; no parameter sweep |
| tb/tb_moving_average.sv | startup/wrap/reconfiguration/invalid/effective-window tests |
| tb/tb_voice_stability_top.sv |128 scores/states/averages,reset abort,enable,backpressure,threshold/equality; prints latency but has no <1ms assertion |
| tb/test_vectors.mem; tb/README.md |128 fixed320-bit vectors; fixture format and coverage description |
| build/weights.tsv |408 Q12 entries matching deterministic generator, not trained model |
| reports/model.json; reports/qor.json | activation error numbers; all RTL/PPA stages unestablished |
| scripts/run_sim.sh | auto Icarus/Verilator/Xcelium;3 benches; requires PASS markers; writes artifacts, therefore not invoked |
| scripts/run_lint.sh | Verilator warnings nonfatal; Icarus fallback syntax-only yet same lint_pass marker |
| scripts/run_synthesis.tcl | Genus templates, source+Liberty+SDC,require pass files; area/timing/power exports,no measured activity import |
| scripts/run_sta.tcl | Tempus mapped/routed selection and optional SPEF; report generation template |
| scripts/run_pnr.tcl | Innovus nominal MMMC/floorplan/place/CTS/route/extract/GDS; PDK-dependent prerequisites |
| scripts/run_drc_lvs.sh | external wrappers/decks and reports required; report existence not proof of clean signoff |
| scripts/report_qor.py | marks artifact presence, leaves metrics unknown; can extract printed latency only with sim marker |
| constraints/top.sdc |20ns clock,0.2ns uncertainty,external input/output delays and load; no exceptions; library units need validation |
| constraints/floorplan.tcl |parameterized PG/floorplan,all pins on left,technology-specific geometry required |
| config/parameters.mk; tech_config.example.mk |target values largely not propagated; placeholder paths,PG/CTS parameters and signoff wrappers |
| Makefile |model regeneration precedes sim/test/synth; targets write protected-for-this-phase artifacts; verification markers not source-hashed |
| .github/workflows/rtl-ci.yml |install tools and make test reports from checkout root; nested workspace layout must be corrected in later CI packaging; no CI result supplied |

## Data and control trace

Top ready=rst_n&&enable&&!busy; accept=valid&&ready captures features and starts cell on the same edge. Controller first enters INIT, so later MAC cycles see the captured buffer. For every z neuron, then every r neuron, then every n neuron: INIT loads bias; MAC consumes I+H terms; FINISH stores activated result. Candidate recurrent operands recompute round(r[k]*h_old[k]) combinationally per term. UPDATE blends one next neuron per clock, then COMMIT writes the whole bank. Old state remains unchanged throughout gate calculation. done is combinational COMMIT; top registers pending=done, score_valid=pending. Score is always combinational from hidden state, so score may change before score_valid; it is not a result holding register. Average samples score_valid on the following edge; average_valid trails score_valid. Alert immediately reflects average and live threshold. Busy includes cell_busy,pending,score_valid; admission is held off during drain. Enable affects only admission; reset aborts and clears state/valids. There is no frame_done named signal, no flush or IRQ. Prototype count to score is analytically3H(I+H+2)+H+2=442 cycles for8/8; not measured here.

## Additional risks and duplicated cost

* Matrix MAC is shared, but r*h, two blend products, PWL interpolation and output sum/projection are outside it. Tanh has its own sigmoid instance and score has another. Mapping may optimize constants; do not claim an exact physical multiplier count without synthesis.
* Signed 16-bit coefficient storage contradicts INT8 even when many coefficients happen to fit. Bias semantics are Q12 shifted12 in the prototype, versus F19 aligned in target.
* Constant divisions by4096 in PWL or elaboration-time4096/H are not equivalent to the average's variable divisor. Target removes variable division; netlist inspection remains necessary.
* Existing checks share knot constants/equations with RTL; mathematical error sweep provides a separate check but no trained-model accuracy evidence. Backpressure bench changes feature data while holding valid during busy, so it is not a fully compliant AXI source test.
* Eight-neuron fixtures, constant export loops and default elaboration mask target16-neuron mismatch. Merely exporting Make variables does not override module parameters.
* Fixed mean(h) head has a narrow approximate sigmoid(−1…1) score range and cannot replace a trained calibrated output head. No voice corpus, feature manifest, labels, optimizer, checkpoint, QAT or evaluation pipeline exists.
* Bare pass-marker files can become stale; future evidence must bind source/vector/model/tool hashes. Lint marker does not mean warning-free lint, nor full lint when Icarus fallback is used.
* SDC is reasonable template only; timing/IO load units and clocks must change with target contract. PnR is nominal-corner, lacks qualified physical-only-cell/antenna/fill/multi-corner integration. Power reports use default activity. No valid low-milliwatt inference follows.

## Requirement-by-requirement assessment

SATISFIED requires adequate demonstrated compliance, not mere file existence. PARTIALLY SATISFIED means implementation or evidence covers a subset; NOT SATISFIED identifies a concrete mismatch; NOT VERIFIED means the performance/quality/long-run claim lacks proof. No requirement is marked NOT APPLICABLE because all apply to this project. No overall requirement is marked SATISFIED in the current prototype. Exact requirements and detailed evidence/change/test mappings are also in [CSV](requirements_traceability.csv).

| ID | Exact requirement | Status | Source evidence / current behavior | Gap / required change | Verification |
|---|---|---|---|---|---|
| R01 | Implement a small recurrent neural network, preferably a GRU; justify any LSTM alternative. | PARTIALLY SATISFIED | rtl/gru_cell.sv:23-52; model/gru_reference.py:27-38: Reset-before GRU gate equations and state blend exist. | GRU structure present; RTL functional equivalence unexecuted. Retain reset-before GRU; share all arithmetic. | T-GRU |
| R02 | Process voice-quality feature vectors at intervals of 10–20 ms. | PARTIALLY SATISFIED | rtl/voice_stability_top.sv:15-18; tb/tb_voice_stability_top.sv:33-59: Ready/valid accepts precomputed vectors. | No cadence-level sustained verification; no feature semantic contract. Define host normalization/cadence and backpressure. | T-STREAM |
| R03 | Support 8–16 input features. | PARTIALLY SATISFIED | rtl/gru_cell.sv:1; model/generate_weights.py:19-22: INPUTS parameter exists, default 8. | Fixtures and export hard-code 8; no range sweep. Elaboration range 8…16 and dimension-aware export. | T-DIM |
| R04 | Use 16–32 hidden units. | NOT SATISFIED | rtl/voice_stability_top.sv:1; config/parameters.mk:4: Actual RTL defaults to HIDDEN=8. | Make variable HIDDEN=16 is not passed into elaboration. Baseline16; support legal range through 32. | T-DIM |
| R05 | Use INT8 neural-network weights and INT16 activations. | NOT SATISFIED | rtl/weight_rom.sv:4-14; rtl/mac_unit.sv:3: Weights and activation ports both 16-bit Q12. | Stored artifact has 197/384 weights outside signed 8-bit. Signed8 F7 weight arrays and signed 16-bit F12 activations. | T-ARITH; T-LOAD |
| R06 | Use a time-multiplexed MAC architecture instead of a completely parallel implementation, prioritizing low area and low power. | PARTIALLY SATISFIED | rtl/gru_controller.sv:18-27; rtl/gru_cell.sv:36-40: Matrix terms reuse one mac_unit; reset/blend use other multipliers. | Area and switching unmeasured; duplicate arithmetic. Reuse one physical multiplier for all neural products and head. | T-SCHED; T-PPA |
| R07 | Implement sigmoid and tanh approximations using LUTs or another justified low-cost approximation. | PARTIALLY SATISFIED | rtl/sigmoid_lut.sv:4-19; rtl/tanh_lut.sv:4-11: PWL knots and sigmoid identity; Python error grid passes. | RTL LUT equality and hardware cost unverified. Direct ROMs, declared errors, no interpolation multiplier. | T-LUT |
| R08 | Maintain recurrent hidden state across frames belonging to the same call. | PARTIALLY SATISFIED | rtl/hidden_state_reg.sv:6-8; model/gru_reference.py:35-38: State persists until reset and commits vector together. | Python continuity passes; RTL not run. Retain old/next banks and atomic commit. | T-STATE |
| R09 | Provide a mechanism to flush recurrent state at the beginning of a new call. | NOT SATISFIED | rtl/hidden_state_reg.sv:1-9; rtl/voice_stability_top.sv:1-10: Only full reset clears h. | No call-start command. Deferred flush abort with completion acknowledgement. | T-FLUSH |
| R10 | Generate a voice-stability score between 0 and 1. | PARTIALLY SATISFIED | rtl/stability_score.sv:9-19: Unsigned bounded sigmoid(mean(h)) code. | Untrained projection has no validated voice-quality meaning. Learned projection and calibrated score; UQ0.16. | T-SCORE; T-QUALITY |
| R11 | Maintain a running average of the stability score. | PARTIALLY SATISFIED | rtl/moving_average.sv:17-38: Circular window sum/valid count; Python averages checked. | RTL not verified and divider violates R13. Shift EMA, exact startup and rounding contract. | T-EMA |
| R12 | Generate an alert when the averaged score indicates degraded voice quality, using hysteresis to avoid alert oscillation. | NOT SATISFIED | rtl/alert_controller.sv:6: Combinational initialized && average<threshold. | No latched alert or recovery band. Stateful strict low/high thresholds. | T-ALERT |
| R13 | Avoid hardware dividers. | NOT SATISFIED | rtl/moving_average.sv:38: new_sum/new_count variable division. | No evidence synthesis removes variable divider. Shift EMA; direct LUTs; no variable divide datapath. | T-EMA; T-PPA |
| R14 | Support a configurable threshold and the required control, status, and interrupt functions. | PARTIALLY SATISFIED | rtl/voice_stability_top.sv:3-9: Threshold/window/enable pins and busy/valid outputs. | No register bus, IRQ, sticky status, loading. CSR and loader map with W1C IRQs. | T-CSR; T-IRQ |
| R15 | Support suitable input and control interfaces for integration into a telecom edge device. | PARTIALLY SATISFIED | rtl/voice_stability_top.sv:3-18: Local packed frame handshake. | No documented AXI subset/CSR integration contract. Packed AXI-Stream subset plus local register bus. | T-AXIS; T-CSR |
| R16 | Meet the frame-processing latency requirement of less than 1 ms. | NOT VERIFIED | rtl/gru_controller.sv:18-28; reports/qor.json: Prototype analytical score latency 442 clocks at baseline8/8. | No simulator measurement or timing closure. 1547-cycle baseline allocation at candidate 10 MHz. | T-LATENCY; T-PPA |
| R17 | Target low-milliwatt power consumption, subject to measurement under explicitly documented technology, clock, voltage, workload, and activity assumptions. | NOT VERIFIED | reports/qor.json; scripts/run_synthesis.tcl: Power metrics NOT MEASURED; default-activity report template. | No library, voltage or representative activity evidence. Clock enables/ICG and annotated workload-based estimates. | T-POWER |
| R18 | Be verified against a Python reference model. | PARTIALLY SATISFIED | model/gru_reference.py; tb/tb_gru_cell.sv:51-55: 128 integer vectors match current model in audit. | No RTL execution evidence; target arithmetic differs. New bit-exact target oracle and scoreboard after approval. | T-GRU; T-SCORE |
| R19 | Support long-running operation, including a one-hour equivalent continuous-stream verification. | NOT VERIFIED | tb/tb_voice_stability_top.sv:33: Only128 frames. | No180000/360000-frame run or count-wrap coverage. Persistent360000-frame test plus cadence checks. | T-STREAM |
| R20 | Include appropriate verification for reset, saturation, back-to-back frames, state continuity, state flushing, threshold crossing, and other corner cases. | PARTIALLY SATISFIED | tb/tb_voice_stability_top.sv; tb/tb_gru_cell.sv; tb/tb_moving_average.sv: Directed checks exist for subset of prototype features. | No executed RTL results; no flush/hysteresis/CSR tests. Directed/random tests and temporal assertions. | T-RESET; T-ARITH; T-STATE; T-FLUSH; T-AXIS; T-ALERT |
| R21 | Quantify the effects of fixed-point quantization and activation approximations. | PARTIALLY SATISFIED | model/gru_reference.py:76-97; reports/model.json: Exhaustive existing PWL error reproduced. | No floating/trained model quantization-loss analysis. Separate arithmetic, LUT, clipping and end-task quality loss. | T-LUT; T-QUALITY |
| R22 | Support synthesis and physical-design evaluation where suitable technology libraries and tool licenses are available. | PARTIALLY SATISFIED | scripts/run_synthesis.tcl; scripts/run_pnr.tcl; constraints/top.sdc: Unexecuted tool/technology-dependent templates. | No licensed tools on PATH or configured local technology; nominal corner only. Validate tool dialect, constraints, MMMC and activity flow later. | T-PPA; T-POWER |
| P01 | Input: a feature vector every 10–20 ms, including jitter, packet-loss flag, energy, SNR estimate and selected spectral features; 8–16 features delivered over AXI-Stream. | PARTIALLY SATISFIED | docs/problem_statement.md; rtl/voice_stability_top.sv: Local handshake, synthetic arbitrary Q12 values. | Original is more specific than user R15; semantics absent. AXI-compatible subset and dataset feature manifest. | T-AXIS; T-QUALITY |
| P02 | Recurrent core: one GRU or LSTM layer with 16–32 hidden units. INT8 weights and INT16 activations, with quantization-aware training. | NOT SATISFIED | docs/problem_statement.md; model/generate_weights.py:1-9: Deterministic untrained coefficient hash. | Original explicitly requires QAT; no training pipeline or dataset. Train reset-before16-unit GRU with QAT and target arithmetic. | T-QUALITY; T-LOAD |
| P03 | Control: register map for enable, threshold, window/averaging configuration, status and weight loading. Clock gating when idle. | NOT SATISFIED | docs/problem_statement.md; rtl/voice_stability_top.sv: Pin-level controls and constant coefficient ROM only. | No loading/CSR/ICG; conditional updates are not demonstrated clock gating. Sequential load interface, enables and qualified ICG insertion. | T-LOAD; T-CSR; T-POWER |
| P04 | Accuracy: score correlation with a reference quality metric (MOS/PESQ-derived) above a threshold declared by the team. | NOT VERIFIED | docs/problem_statement.md; model/gru_reference.py: No quality dataset, labels or correlation measurement. | Original accuracy obligation absent from user numbered list. Propose 0.80 Pearson target, get data-owner approval; evaluate held-out calls. | T-QUALITY |
| P05 | Bit-accurate comparison between Python/NumPy golden model and RTL (cocotb or UVM). | PARTIALLY SATISFIED | docs/problem_statement.md; tb/*.sv: Static vectors checked by procedural SV benches. | No cocotb/UVM framework or RTL pass evidence. Use cocotb plus SV assertions; retain portable vectors. | T-GRU; T-STREAM |

## Documentation change verification

A SHA-256 before/after comparison confirmed all 48 pre-existing non-README files remained byte-identical; exactly the ten requested documents were added. The README received review links, removal of its unsupported tracked-file count, and corrections to current simulator availability/next-step wording. Historical Python result values were preserved. Local document links, all 27 requirement IDs, every referenced test ID and baseline/maximum cycle arithmetic were checked successfully. These are documentation integrity checks, not RTL tests.
