# Phase 0/1 review — mathematical specification and architecture approval

**Phase 0 and Phase 1 are complete. Stop before Phase 2.** No new Python inference/training/quantization, RTL or testbench was implemented. Existing design sources and artifacts were preserved; no files deleted. This review replaces the previous review's execution status and broad implementation sequence. Approval must explicitly identify the next phase and does not authorize the remaining phases automatically.

## Repository findings and recovery

The current prototype has8 inputs/8 hidden units, signed16 Q12 weights/activations, a40-bit matrix accumulator and atomic recurrent state. It uses untrained deterministic weights, extra arithmetic outside the matrix MAC, a mean-state score, variable-divider averaging and a combinational threshold. Flush, hysteresis, learned head, CSR, loader and interrupt remain missing. The Make HIDDEN16 value is not an RTL parameter override. [Phase0 audit](phase0_audit.md) gives the complete62-file starting inventory, reuse classifications and actual tests; [prior detailed source audit](architecture_audit.md) remains historical source-reference material, not the current execution ledger.

Git status and branch are unavailable at both roots because no Git metadata exists. All files were treated as user changes to preserve. A hash-verified62-file recovery snapshot was created before edits under `../recovery/phase0-20261010T194104Z/` relative to the project root. Restore instructions, SHA-256 manifest and source-bound audit logs are there. No destructive operation was performed.

## Research findings and final proposed mathematics

All three local papers were reviewed. [Research paper review](research_paper_review.md) records page/equation citations and PDF hashes. CHO main equations(5)–(8) and AppendixA.1 encoder confirm reset-before and z weighting old state; AppendixA.1 makes tanh and zero initialization explicit and says biases were omitted for clarity. Its appendix decoder places reset differently. QUANT equation(13) reverses z polarity and uses [h,x] column ordering. HW supports explicit controllers and reused resources, but its two PEs are not two scalar MACs or an ASIC power result.

Chosen mathematical baseline (one bias-enabled layer, I=8,H=16; configurable within PS-01 ranges):

```
r = sigmoid(W_r x + U_r h_old + b_r)
z = sigmoid(W_z x + U_z h_old + b_z)
n = tanh(W_n x + U_n (r ⊙ h_old) + b_n)
h_new = z ⊙ h_old + (1−z) ⊙ n
s = W_s h_new + b_s
p = sigmoid(s)
```

All vectors are columns; W_g is H×I, U_g H×H, b_g H×1, W_s 1×H and b_s scalar. Store rows in z,r,n order with input columns before recurrent columns. h starts at zero and persists across successful frames; flush starts a new call. Equations and orientation are fully specified in [gru_mathematical_specification.md](gru_mathematical_specification.md). The learned scalar head, EMA and alert are PS-01 engineering choices, not translation-paper prescriptions. The output's quality meaning depends on labels/training, not sigmoid alone.

## Proposed hardware and changes

Retain the previous target's one shared16×16 multiplier, sign-extended INT8 weights,40-bit accumulator, explicit FSM, weight/bias storage, direct activation ROMs, old/next state and gate scratch. Candidate formats are F7 weights,F12 activations,F19 aligned signed32 biases; they are not numerically validated trained formats. Add learned shared head, rounded shift EMA(K0…8), strict low/high hysteresis, packed AXI-compatible frame input, simple CSR bus, sequential loader, flush acknowledgement and masked sticky W1C IRQs. Use clock enables with later qualified ICG mapping. No hardware divider.

Relative to the **current RTL**, this changes dimensions/weight precision, shares auxiliary arithmetic, replaces score/average/alert logic and supplies missing controls. Relative to the **previous proposal**, the principal changes are research provenance, explicit bias/matrix/gate conventions, candidate-format status, simulator evidence, clearer EMA-versus-window interpretation and mandatory separate phase gates. It does not replace the existing source.

| Analytical target quantity | 8-input/16-hidden | 16-input/32-hidden |
|---|---:|---:|
| GRU + head matrix MACs |1168|4640|
| Reset + blend multiplies |48|96|
| Total multiplier operations |1216|4736|
| Allocated schedule cycles |1547|5387|
| C+1 latency ceiling at candidate10MHz |154.8µs|538.8µs|

These budgets include coefficient reads, bias load, LUTs, reset/blend, head, state commit and completion. They are **analytical**, not target simulations or physical timing. One MAC is a feasible baseline, not proven optimal area/energy; compare additional lanes and memory bandwidth after measurement. See [schedule](datapath_and_scheduling.md) and [architecture](final_architecture.md).

## Checks and tests actually executed

* Hash-verified starting archive and file inventory; Git/tool/package discovery; local paper text and critical equation-page review.
* Existing Python arithmetic/state/average checks passed; existing128 vector rows and408 weight/bias rows matched the old model/generator. Existing PWL errors reproduced: sigmoid0.01807698997125361, tanh0.03614531386627384.
* Icarus11 moving-average bench passed. Icarus cell/top **failed elaboration** on weight_rom integer input ports.
* Verilator5.038 lint completed with **seven width-expansion warnings** under -Wno-fatal. Initial binary builds failed on sandbox ccache directory writes; approved retries outside the sandbox passed the unchanged cell and top benches. The top reported **442 cycles to score_valid** at a20ns simulated clock, corresponding to8.84µs for the8/8 prototype only.
* Documentation local links, CSV/test/requirement references, source preservation and operation/schedule arithmetic were checked. Exact changed paths and hashes are in the recovery run_manifest.json.

No target model/RTL, one-hour test, training/QAT, target quantization/LUT experiment, synthesis, STA, power, PnR or signoff was executed. A prototype bench PASS is not complete PS-01 compliance. Current reports/qor.json remains an untouched historical artifact; new evidence is in the recovery archive.

## Traceability and remaining compliance

The [CSV](requirements_traceability.csv) preserves27 stable detailed requirement rows and adds mappings to **all15 current PS-01 clauses**, with source/paper/engineering evidence classes. Current counts: 17 PARTIALLY SATISFIED, 7 NOT SATISFIED, 3 NOT VERIFIED; none marked overall SATISFIED or NOT APPLICABLE.

| Current PS-01 clause | Detailed rows | Current assessment |
|---|---|---|
|1 voice-monitoring application|R02,R19,P01|prototype only; no real quality validation or long stream|
|2 cadence/features/input|R02,R03,R15,P01|local handshake/8-feature fixture; semantics and AXI target pending|
|3 GRU/dimensions/precision/QAT|R01,R04,R05,P02|prototype GRU tested;8 hidden/16-bit weights/non-QAT fail mandatory details|
|4 shared compute|R06|matrix reuse exists; target full sharing/PPA pending|
|5 nonlinearities/error|R07,R21|old PWL tests pass; target ROMs unverified|
|6 state/flush|R08,R09|limited persistence tests pass; flush absent|
|7 score|R10|bounded untrained score; learned quality head absent|
|8 average/no divider|R11,R13|old mean tests pass; variable divider violates requirement|
|9 hysteretic interrupt|R12,R14|absent hysteresis and IRQ|
|10 register control/loading/gating|R14,R15,P03|incomplete; no register bank/loading/verified ICG|
|11 latency|R16|prototype simulated442 score cycles; target/physical timing unverified|
|12 power|R17,R22|no PPA or technology-qualified power estimate|
|13 reference-metric correlation|P04|no dataset/trained model/measurement|
|14 quantization loss|R21|activation errors only; float-versus-RTL task loss unavailable|
|15 verification|R18–R21,P05|limited existing benches pass on selected tools; no target/cocotb/one-hour evidence|

## Open decisions, assumptions and blockers

Explicit owner approval blocks Phase2 now. Recommended defaults resolve architecture choices, but feature definitions/normalization, dataset access/labels, correlation threshold confirmation (proposed≥0.80), calibration and FP/FN criteria remain open. Weight F7 is limited to [−1,+0.9921875]; future training may require an approved fractional-scale revision while preserving INT8/INT16. ROM versus PWL and one versus multiple MAC lanes remain measurement-driven trade-offs. Input width/bus bridge, numerical power ceiling, technology/corners/voltage, ICG/DFT resources and Cadence license/releases are unconfirmed.

NumPy is discoverable; Torch/TensorFlow/cocotb/pytest are not in the inspected interpreter. No xrun/genus/innovus/tempus on PATH and no supplied project PDK. These block training/tool-specific implementation stages, **not a NumPy or standard-library Phase2 mathematical reference after approval**. Existing tool-portability warnings are documented future repairs, not fixed in this phase.

## Files changed in this run

Created in docs/:

* research_paper_review.md
* gru_mathematical_specification.md
* phase0_audit.md

Modified in docs/:

* final_architecture.md
* datapath_and_scheduling.md
* interface_specification.md
* numerical_specification.md
* architecture_decisions.md
* architecture_review.md
* requirements_traceability.csv

README.md received links to the new current audit/research/math review. No other project files changed. **Deleted: none.** Outside the project, recovery/phase0-20261010T194104Z contains repository.tar.gz,manifest.json,CHECKPOINT.md,audit_evidence.tar.gz,run_manifest.json. Temporary PDF text/renderings and isolated simulator files remain under /tmp and are enumerated in run_manifest.json; no temporary source was edited. Earlier architecture_audit.md,verification_plan.md,implementation_roadmap.md and other historical docs were preserved.

## Future phase gates

| Phase | Only authorized work when explicitly approved |
|---|---|
|2|floating-point Python GRU reference and unit tests|
|3|dataset/target audit and training pipeline|
|4|QAT, INT8/INT16 conversion and export|
|5|bit-accurate fixed-point Python reference|
|6|SystemVerilog architecture|
|7|MAC scheduling implementation/optimization|
|8|verification rebuild and replacement of obsolete benches where justified|
|9|Cadence toolchain and PDK audit|
|10|synthesis, timing, physical implementation and power evaluation|
|11|obsolete-file cleanup after replacements pass, documentation and final traceability|

Each phase checkpoints, runs relevant checks, reports actual results and stops for approval. **Recommendation: approve Phase2 only**, implementing the checked floating equations and mathematical unit tests; no training, fixed-point model, RTL or testbench edits accompany that authorization. Please review and approve the mathematical specification and architecture before Phase2 begins.
