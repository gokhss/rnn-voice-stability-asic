# Datapath and scheduling

## Authority, evidence and phase boundary

PS-01 in [problem_statement.md](problem_statement.md) is authoritative. [Research review](research_paper_review.md) identifies the paper-supported recurrence and research limitations; [mathematical specification](gru_mathematical_specification.md) fixes the project's bias-enabled reset-before equations. Unless attributed to a paper or PS-01, choices here are engineering proposals. Numeric formats, memory timing, clock and resource assumptions require later validation; open questions are tracked in [architecture decisions](architecture_decisions.md). Only Phase 0/1 are authorized now. Approval of the next phase authorizes **Phase 2 floating-point model and unit tests only**, not RTL, quantization or training. The prior implementation_roadmap.md is background, not phase authorization; the current numbered gates are in [architecture review](architecture_review.md).

Proposed architecture; all performance values are estimates. I=8, H=16 baseline; legal elaboration ranges I=8…16, H=16…32. One physical signed 16-bit×16 multiplier, shared with signed 40-bit accumulator; matrix weights are signed 8-bit. No independent reset-product, blend or score multipliers. Clock candidate 10 MHz; 50 MHz remains a comparison/integration option, not an original problem requirement.

## Equations and dependencies

For each frame, read the immutable old state:

```
z = sigmoid(Wz*x + Uz*h_old + bz)
r = sigmoid(Wr*x + Ur*h_old + br)
q = round_Q12(r .* h_old)
n = tanh(Wn*x + Un*q + bn)
h_next = round_Q12(z .* h_old + (1-z) .* n)
score = sigmoid(v*h_next + b_out)
```

This is reset-before and z weights the old state. Training exports must match both conventions; do not directly import reset-after library GRU coefficients. Each W is H×I, each U H×H, each gate bias H; v has H entries and output bias is scalar. Ordering is all z neurons, all r neurons, all reset products q, all n neurons, all blends, atomic hidden commit, score, average, alert/completion. Candidate cannot begin until the complete q vector exists. The output head uses committed next state.

Gate weight flat address = (g*H+j)*(I+H)+t, g=0 z,1 r,2 n; t<I reads W, otherwise U. Output v begins at 3H(I+H). Bias address gH+j, output bias 3H. Within all vectors index zero occupies least-significant lane. Bias and weight arrays have independent read interfaces. One-cycle synchronous coefficient read is assumed; addresses and operand indices pipeline together. No memory stalls are permitted in the internal execution budget.

## Operations and concrete schedule

Matrix terms: 3H(I+H). Baseline 3*16*24=1,152 (384 per gate). Output head adds H=16, giving **1,168 matrix MACs**. Reset products add H=16 multiplies; hidden blends add 2H=32. Total **1,216 multiplier operations**, plus bias loads, shifts, LUTs, additions and comparison. Candidate reset products are computed once per frame, not H times.

Each dot product of N terms is allocated N+5 clocks:

| Stage | Clocks | Work |
|---|---:|---|
| Bias/address | 1 | issue bias read |
| Initialize/prefetch | 1 | load returned bias; issue term 0 |
| MAC loop | N | accumulate returned weight × correctly delayed operand; prefetch next term |
| Requantize | 1 | round/saturate accumulator into preactivation register |
| Activation request | 1 | issue magnitude address and function/sign |
| Activation write | 1 | write synchronous LUT result |

Each q element uses 3 clocks (multiply/register, round, write). Each blend uses 5 (clear accumulator, first multiply/add, second multiply/add, round, write next-state). Admission/start allowance 2; hidden atomic commit 1; EMA 1; alert and public score/average/done publication 1; drain 1. The scheduler deliberately avoids overlapping these administrative steps.

C(I,H) = 2 + 3H*(I+H+5) + 3H + 5H + 1 + (H+5) + 1 + 1 + 1
       = 3H*(I+H+5) + 9H + 11.

Baseline C=1,547 clocks, maximum I=16,H=32 C=5,387. This is the acceptance-to-drain allocation; publication occurs by C and admission resumes on the next eligible idle edge. Define a verification ceiling of C+1 to cover edge-count convention, not unexplained pipeline stalls. Measure from the edge of valid&&ready to frame_done, including average and alert. Allocation includes coefficient access, all elementwise arithmetic, score, and completion; excludes upstream waiting before acceptance and loading a model.

| Configuration | At 10 MHz | At 50 MHz | Conservative min clock for <1 ms |
|---|---:|---:|---:|
| 8/16, 1 MAC | ≤154.8 µs | ≤30.96 µs | >1.548 MHz |
| 16/32, 1 MAC | ≤538.8 µs | ≤107.76 µs | >5.388 MHz |

Baseline sustainable rate ≥10^7/1548≈6,460 frames/s (not a measured throughput). At 100 frames/s compute duty ≤1.548%; maximum dimensions ≤5.388%. At 50 frames/s these halve. No frame queue is required for periodic 10–20 ms input, but a stalled producer must honor backpressure. Wall-clock feature extraction and integration queues have separate budgets. Clock reduction saves switching per unit time at fixed activity, but per-frame compute energy, leakage and memory/clock overhead require measurement; utilization alone does not establish milliwatts.

## Alternatives (not implemented)

For comparison only, P neuron-parallel MAC lanes with duplicated/banked coefficient bandwidth and gate scratch access give C_P≈3*ceil(H/P)*(I+H+5)+8*ceil(H/P)+ceil(H/P)+11. The output uses P partial accumulators; add ceil(log2(P)) reduction cycles. Assumes P divides H and sufficient independent ports; includes the same approximate per-neuron overhead and optimistic parallel elementwise work.

| Lanes | Baseline estimated cycles | 10 MHz latency | Area / switching / scheduling implications |
|---:|---:|---:|---|
| 1 | 1547 | 154.7 µs | minimum datapath and memory bandwidth; serial FSM |
| 2 | ~780 | ~78.0 µs | two multipliers/accumulators, banks, reduction; higher active switching, energy not guaranteed lower |
| 4 | ~397 | ~39.7 µs | four lanes and wider memory read, more routing and control; unnecessary latency margin |

Parallel figures are comparative estimates, not target cycle contracts. Full parallel matrices conflict with the area/power priority. One reused MAC meets even maximum dimensions at the recommended clock with substantial analytical margin, so additional lanes have no demonstrated need. Timing closure on the multiply-plus-accumulate path remains a synthesis/STA obligation. If a selected technology needs extra pipeline stages, revise schedule and repeat analysis before implementation approval of that change.

## Baseline and maximum analytical accounting

| Item | Formula | I=8,H=16 | I=16,H=32 |
|---|---|---:|---:|
| Each gate matrix terms | H(I+H) | 384 | 1536 |
| All three gates | 3H(I+H) | 1152 | 4608 |
| Output-head MACs | H | 16 | 32 |
| Reset products | H | 16 | 32 |
| Blend products | 2H | 32 | 64 |
| Total multiplications | 3H(I+H)+4H | 1216 | 4736 |
| Matrix bias initializations / nonlinear evaluations | 3H+1 | 49 | 97 |
| Gate dot schedules including reads/LUTs | 3H(I+H+5) | 1392 | 5088 |
| Reset-product clocks | 3H | 48 | 96 |
| Blend clocks | 5H | 80 | 160 |
| Head including bias/read/LUT | H+5 | 21 | 37 |
| Admit+commit+EMA+publish+drain | 2+1+1+1+1 | 6 | 6 |
| Total allocated clocks | C(I,H) | 1547 | 5387 |

| Resource storage (not mapped area) | Baseline | Maximum |
|---|---:|---:|
| INT8 weights, including head | 1168 bytes | 4640 bytes |
| INT32 biases | 196 bytes | 388 bytes |
| Six H×16 old/next/gate/q banks | 192 bytes | 384 bytes |
| Captured features | 16 bytes | 32 bytes |
| Activation ROMs | 1540 bytes | 1540 bytes |

Coefficient storage excludes loader/CSR/control registers. Tables may synthesize into mux logic or a macro; bytes are not an ASIC area estimate. The one-cycle MAC and memory service are assumptions. No combinational matrix adder tree or separate score multiplier is hidden in the budget.

For maximum dimensions the same optimistic P-lane comparison gives about 2700 clocks at P=2 (270.0 µs at 10 MHz) or 1357 clocks at P=4 (135.7 µs), versus 5387 for one. Parallel lane counts are engineering what-if calculations, not the HW paper's measured PE schedules. More lanes require bandwidth/banking, duplicated accumulators and reductions; leakage and instantaneous switching can rise even if active time falls. A single scalar MAC is the simplest feasible baseline, not a conclusion about optimal energy. Revisit after Phases 7/9/10 evidence.

## Distinguish the four kinds of performance evidence

1. **Mathematical operation count:** exact for the selected equations, as tabulated above.
2. **Analytical schedule:** 1547/5387 allocated clocks, candidate 10 MHz, with C+1 verification ceiling; unimplemented and unverified.
3. **Simulation observation:** this Phase 0 ran the existing unchanged 8-input/8-hidden prototype top bench with Verilator 5.038; it reported **442 clocks to score_valid**. At that bench's 20 ns clock this corresponds to 8.84 µs simulated score latency. It excludes target changes and uses score_valid, not the new frame_done endpoint including average/alert. It is not evidence for target16/32 configurations.
4. **Physical timing:** no mapped timing, post-route timing or silicon measurement exists. Neither a simulator clock nor an SDC target establishes timing closure.

Original logs and source checkpoint are preserved as described in phase0_audit.md. Paper facts are limited to HW's reuse/dataflow example; all PS-01 cycle estimates here are our engineering analysis.
