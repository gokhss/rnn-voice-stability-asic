# Architecture decisions and review assumptions

## Authority, evidence and phase boundary

PS-01 in [problem_statement.md](problem_statement.md) is authoritative. [Research review](research_paper_review.md) identifies the paper-supported recurrence and research limitations; [mathematical specification](gru_mathematical_specification.md) fixes the project's bias-enabled reset-before equations. Unless attributed to a paper or PS-01, choices here are engineering proposals. Numeric formats, memory timing, clock and resource assumptions require later validation; open questions are tracked in [architecture decisions](architecture_decisions.md). Only Phase 0/1 are authorized now. Approval of the next phase authorizes **Phase 2 floating-point model and unit tests only**, not RTL, quantization or training. The prior implementation_roadmap.md is background, not phase authorization; the current numbered gates are in [architecture review](architecture_review.md).

Status: selected proposal awaiting user approval. The primary problem leaves bus details, clock, scale and threshold values to the team. Rows below justify recommendations rather than inventing mandates. R identifiers refer to requirements_traceability.csv. No area or power number is measured.

| Decision | Motivation / alternatives / requirements | Area impact | Power impact | Latency impact | Verification implication |
|---|---|---|---|---|---|
| D01 GRU 8/16, elaboration8…16/16…32 | meets R01–04 with smallest legal baseline; LSTM adds cell state/gate work without demonstrated quality need | smallest legal recurrent bank/matrices | fewer multiplies than larger model; quality must be checked |1547-cycle allocation baseline | dimension sweep, quality comparison |
| D02 reset-before; z retains old h | preserve existing coherent convention; reset-after changes model, not interchangeable | q bank H×16 | compute q once vs every candidate row |3H clocks for q | gate checkpoint equality and asymmetric reset tests |
| D03 one 16×16 physical multiplier, signed 8-bit stored weights | R05–06; auxiliary activation products need16-bit operands; alternate16×8 core plus separate elementwise engine costs more resources | one multiplier somewhat larger than16×8, removes separate blend/reset/head arithmetic | reduces duplicated switching/clocked hardware; energy unmeasured | includes3H elementwise products | netlist resource inspection, signedness assertions |
| D04 signed 40-bit accum, F12 activations/F7 weights/F19 biases | R05/21; explicit bounds; per-tensor programmable shifts rejected initially for complexity |40-bit accumulator,32-bit biases | wider acc costs switching; clock-enable idle | single-cycle accumulate assumption at 10 MHz | overflow proof and boundary tests; QAT must accommodate fixed range |
| D05 symmetric direct ROM nonlinearities | R07/21; replaces PWL's interpolation multipliers; error targets better than existing PWL |1540 table bytes before synthesis; technology mapping may dominate | avoids interpolation toggle, ROM access cost must be measured | synchronous lookup included inN+5 dot budget | exhaustive65536-point errors and frozen image hashes |
| D06 old/next atomic banks with z/r/q/n scratch | R08; prevents partial recurrent updates; no multi-call context swapping |6H×16 bits | enabled writes only |one commit cycle | read-before-write and persistence assertions |
| D07 learned sigmoid output head | R10 and source quality criterion; fixed mean head is untrained and inflexible |H INT8 weights plus one bias, reuses MAC |H extra MACs/frame |H+5 clocks | head oracle and held-out calibration |
| D08 first-sample-initialized rounded shift EMA K0…8 | R11/13; replaces variable-divide window; K4 default |16-bit avg, signed difference/shifter; no history RAM | lower state/memory traffic, no divider |one scheduled EMA cycle | tie/deadband/initialization checks |
| D09 strict low/high hysteresis, atomic pair | R12/14; defaults0.5/~0.6 are recommendations, not calibrated thresholds |two comparators and alert flop | transition-only event state |one publication stage | equality, misconfiguration and real FP/FN tests |
| D10 packed AXI-stream subset, one buffer | R02/15 and P01; no serialization or extra bus complexity |128-bit baseline buffer; wide pins may cost integration area |one capture per frame |one acceptance; producer waits while busy | compliant held-valid/backpressure tests |
| D11 local 32-bit CSR bus with external SoC bridge | R14/15; AXI-Lite not mandated for control |smaller than complete bus protocol engine |always-responsive small register domain |one-edge transaction | alignment, permission and event-priority coverage |
| D12 sequential disabled-only model load,8-bit memory | P03; runtime load avoids synthesis per model, no second bank or bitmap |1364 coefficient bytes baseline, index/model-valid metadata |idle-only loads; exclusive ports |model setup outside frame latency | complete coverage and sign-extension checks |
| D13 deferred flush aborts work; resets per-call avg/alert | R09/20; drain policy would delay new-call boundary |pending flag and clear distribution |one reset-like clearing event/call |one edge after command acceptance | request-edge races and canceled-frame accounting |
| D14 synchronous active-low reset invalidates model | preserve existing reset convention; no asynchronous deassertion CDC added |reset small banks/control, not coefficient bits |no coefficient reset network |reload needed after reset | reset every phase/load; valid prevents stale coefficient use |
| D15 holding results + DONE pulse + sticky masked IRQ | R14 and original interrupt requirement; FIFO unnecessary at50–100fps |small register/event bank |updates only on events |IRQ assertion coincident publication | W1C races/coalescing and software servicing contract |
| D16 candidate 10 MHz, enables then qualified ICG | R16–17/P03;50MHz is historical example, not required; no raw RTL clock AND |ICG overhead vs clock tree savings unknown |less unnecessary idle activity, representative measurement required |maximum dimension<539µs analytically | STA, gated equivalence and clock-gating checks |
| D17 portable oracle/cocotb, technology-specific backend | R18–22/P05; UVM alternative if required by integration |no functional datapath overhead; DFT later |activity measurement needed, not synthetic PPA claims |test/debug effort only | evidence tied to exact source/tool/PDK versions |

## Resolved details and unresolved validation

All architectural A–W decisions have defaults defined in the companion specifications. No model is trained, no feature normalization is frozen, and no PDK/voltage/tool license is supplied. Those omissions do not justify inventing implementation results.

1. User must review and approve this Phase 1 architecture before any implementation change. This is the explicit task gate.
2. Dataset owner must confirm eight feature definitions and units, MOS/PESQ-derived label normalization, leakage-free call splits, cadence, scenario coverage and permitted data access. Suggested 0.80 correlation and quantization/FP/FN limits in numerical_specification.md are proposed team criteria awaiting confirmation. Synthetic-only bring-up belongs to the separately authorized relevant phase and cannot establish predictive value.
3. Fixed F7 weights limit magnitudes to about1; QAT must demonstrate adequate quality under this range. If not, re-review global/per-tensor shifts or feature normalization with exact new arithmetic and tests. Do not silently rescale exported coefficients.
4. SoC integration must confirm packed AXI width, simple bus bridge, single clock/reset and flush sequencing. Default is one synchronous domain, one call, no output FIFO; add CDC/serialization only with a real requirement and revised latency/area review.
5. PDK owner must supply Liberty/LEF/RC/GDS and corners/voltage/temperature, approved ICG/DFT cells, timing and physical constraints. Tool owner must validate releases/licenses and command dialects. Default 10 MHz is a design budget, not evidence of timing closure.
6. “Low milliwatt” has no numerical ceiling in the source. Report actual annotated average/active/idle power and method; team should agree a numeric target before PPA acceptance. Do not manufacture a technology-independent power number.

No reason currently supports switching to LSTM, more MAC lanes, multi-call context RAM, hardware audio feature extraction, full AXI-Lite or hardware division. Revisit decisions only when measurements or integration requirements justify the additional cost.

## Research review decisions added in this run

| ID | Evidence and decision | Implication |
|---|---|---|
| D18 mathematical source | CHO §2.3 equations (5)–(8) and Appendix A.1 encoder; tanh/bias omission checked | fixed z-preserves-old reset-before convention; no context-conditioned decoder import |
| D19 explicit bias parameterization | paper omits biases for clarity; choose one b_z/b_r/b_n plus scalar b_s | 3H+1 signed32 stored biases; no separately reset recurrent bias; test bias effects in Phase 2 |
| D20 secondary paper isolation | QUANT equation (13) reverses z and concatenates [h,x]; HW uses two PEs and PTQ | do not copy equations/weights by name; no PTQ substitution or assumed two-scalar-MAC equivalence |
| D21 candidate numerics | F7 range [−1,+0.9921875] and F12 recurrence require empirical validation | explicit candidate, no accuracy claim; Phase 4/5 may propose a reviewed scale revision |
| D22 phase authorization | user's latest numbered phases supersede broad earlier roadmap | next approval covers floating reference/tests only; every later phase stops independently |

Biases, the learned voice-quality head, EMA, thresholds and the control map are engineering decisions consistent with PS-01, not a complete ASIC specification from any paper. Initial 8/16 dimensions and one MAC remain baseline recommendations. Available NumPy is sufficient to begin Phase 2 after approval; absent training frameworks/data do not block a floating mathematical reference. Existing Icarus port elaboration failure is a future portability fix, not authorization to edit RTL now.
