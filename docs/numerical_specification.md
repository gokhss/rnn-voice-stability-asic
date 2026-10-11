# Numerical specification — proposed approval baseline

## Authority, evidence and phase boundary

PS-01 in [problem_statement.md](problem_statement.md) is authoritative. [Research review](research_paper_review.md) identifies the paper-supported recurrence and research limitations; [mathematical specification](gru_mathematical_specification.md) fixes the project's bias-enabled reset-before equations. Unless attributed to a paper or PS-01, choices here are engineering proposals. Numeric formats, memory timing, clock and resource assumptions require later validation; open questions are tracked in [architecture decisions](architecture_decisions.md). Only Phase 0/1 are authorized now. Approval of the next phase authorizes **Phase 2 floating-point model and unit tests only**, not RTL, quantization or training. The prior implementation_roadmap.md is background, not phase authorization; the current numbered gates are in [architecture review](architecture_review.md).

Status: architecture only, 2026-10-11. This contract supersedes the prototype numerical choices for future implementation; existing source is unchanged. No target arithmetic has been implemented or tested. INT8 weights and INT16 activations are PS-01 requirements. The selected fractional-bit counts, INT32 bias and INT40 accumulator are a candidate contract for later validation, not proven optimal formats. Q labels are supplementary; do not silently change scales or required widths.

## Formats and operations

| Tensor or operation | Storage / signedness | Fraction bits | Encoding and conversion |
|---|---|---|---|
| Feature x | signed 16 | 12 | real = integer / 4096, range −8 to 7.999755859375 |
| Wz, Wr, Wn, Uz, Ur, Un, output v | **signed 8** | 7 | real = integer / 128, range −1 to 127/128 |
| Gate/output biases | signed 32 | 19 | already aligned to matrix products; never shifted on accumulator load |
| Matrix product | signed 24 | 19 | signed 16-bit × signed 8-bit, explicitly sign extended to accumulator |
| Shared multiplier physical result | signed 32 | operation dependent | 16 × 16; sign extend 8-bit weights for matrix mode; no 16-bit weight storage |
| Matrix accumulator | signed 40 | 19 | load bias then add products without intermediate rounding |
| Gate/output preactivation | signed 16 | 12 | sat16(R(acc,7)) |
| z, r | signed 16 | 12 | integer 0…4096, hence exact ONE=4096; actual sigmoid LUT range narrower |
| Candidate n, old h, next h, reset product q | signed 16 | 12 | h and n constrained to −4096…4096 by recurrence and LUT |
| Elementwise product | signed 32 | 24 | r*h, z*h, (4096−z)*n |
| Hidden blend sum | signed 40 | 24 | add both full products, then one R(sum,12) and sat16 |
| Score, average, thresholds | unsigned 16 | 16 | integer / 65536, 65535 is 1−2^-16, not exactly 1 |
| EMA difference and updated sum | signed 18 | 16 | zero extend unsigned operands before signed subtraction/addition |
| EMA shift | unsigned 4 | none | accepted values 0…8 |

`R(v,s)` is nearest integer, ties away from zero: for s>0, sign(v)*((abs(v)+2^(s−1)) >> s); R(v,0)=v. Magnitude and added half use at least one guard bit beyond the source width. `sat16` clamps to [−32768,32767]; unsigned saturation clamps to [0,65535]. All right shifts in this definition act on nonnegative magnitudes. Never rely on language-default signed shifts, implicit expression sizing, or negative integer division. Python uses unbounded integers then explicit bounds; RTL uses the specified widths. Byte and lane decoding is two's complement.

Reset-before recurrence: q[j]=sat16(R(r[j]*h_old[j],12)); n uses q, not unrounded r*h. Blend: h_next[j]=sat16(R(z[j]*h_old[j]+(4096−z[j])*n[j],12)). ONE subtraction is at least signed 17-bit before selecting its known 0…4096 result. Preserve both products until the single blend rounding. Features are latched unchanged; software applies the versioned training normalization, clips and quantizes before delivery. Suggested eight feature roles are jitter, packet-loss indicator, energy, SNR and four selected spectral descriptors. Exact definitions, units, clipping, cadence and normalization constants require the dataset owner; they are not invented mandatory feature encodings.

## Overflow proof

For legal I≤16, H≤32, each unrestricted signed 16-bit × signed 8-bit term has absolute magnitude ≤32768*128=4,194,304. At most 48 terms plus a full signed 32-bit bias gives |acc|≤48*4,194,304+2^31=2,348,810,240 <2^32, safely inside signed 40-bit. Baseline 24 terms gives 2,248,146,944. Output H≤32 gives ≤2,281,701,376. Thus even adversarial legal biases cannot overflow signed 40-bit. Bias limits are enforced by the loader. Product fits signed 24-bit including (−32768)*(−128)=4,194,304.

Starting at zero, n is within ±4096 and z within [0,4096]. The blend is convex, so h remains within ±4096 after rounding; full blend magnitude ≤4096²=16,777,216. Reset product has the same bound. Intermediate products nevertheless use full signed 32-bit and the common signed 40-bit accumulator for straightforward checking. Matrix-to-Q12 clipping is expected for extreme input/bias patterns and raises sticky SAT status; accumulator overflow is unreachable under these bounds and is an assertion failure, not wraparound behavior. SAT also records any other arithmetic clamp excluding deliberate activation-domain clipping and score endpoint encoding. Count clipping separately in offline model evaluation.

## Direct activation ROMs (no interpolation multiplier)

One synchronous activation service selects sigmoid or tanh and returns a signed 16-bit Q12 result one cycle after address issue. Lookup magnitudes are symmetric, with a widened 17-bit absolute input to handle −32768. Address rounding is nearest magnitude, ties away: (abs(x)+32)>>6. One address step is 1/64 in real units.

* Sigmoid: positive table S[k]=round(4096/(1+exp(−k/64))), k=0…512. Clamp address to 512. Positive result S[k]; negative result 4096−S[k]. S[0]=2048 and S[512]=4095. 513 signed 16-bit entries.
* Tanh: positive table T[k]=round(4096*tanh(k/64)), k=0…255; T[256]=4096. Clamp address to 256 (|x|≥4 uses the endpoint). Restore sign after lookup. 257 signed 16-bit entries.

Table generation uses positive nearest rounding, ties upward, and a frozen reviewed integer image/hash. The Python oracle consumes exactly that image but compares it independently against mathematical activations. Offline transcendental functions never enter hardware. Total table bits 12,320 (1,540 bytes), before memory mapping. ROM implementation is technology dependent; combinational mux ROM plus registered output is an allowed implementation of the one-cycle contract.

Analytical maximum absolute error targets over all 65,536 preactivation codes: sigmoid ≤0.0021 (Lipschitz bound 0.25/128 + 0.5/4096); tanh ≤0.0080 (1/128 + 0.5/4096; endpoint clamp error at 4 is <0.00068). These are conservative architectural bounds, **not measured results**. Exhaustive tests must check monotonicity, symmetry, range and these limits. Preactivation clipping error relative to the unclipped accumulator must be reported separately.

## Score and smoothing

Score projection is learned: a=b_out+sum(v[j]*h_next[j]); p=sigmoid(sat16(R(a,7))); score=min(65535,p<<4). This uses the same MAC and LUT as gates. Resolution is 1/4096 even though transported in UQ0.16; the selected finite sigmoid table actually produces codes 16…65520. It remains within [0,1]; representing exact 1 is not a problem-statement requirement. Calibration must assess this resolution and fixed weight range; changing formats requires an architecture revision, not silent per-tensor scale changes.

First completed score after reset/flush initializes avg=score. Thereafter d=signed(score)−signed(avg), delta=R(d,K), avg_next=usat16(avg+delta), K=0…8. K=0 follows score immediately. EMA has no sample counter, circular buffer, multiply or divider. Rounding creates a deadband |d|<2^(K−1); at K=8 it is at most 127 score codes (~0.00194). Preserve this exact behavior in Python. Average updates once per completed frame only. Configuration changes retain history and take effect for the next admitted frame. Comparators use updated average with strict <assert and >recover; equality holds prior alert.

## Quality and quantization acceptance

Hardware equivalence tolerance is zero integer codes at every checkpoint. Activation error limits above are mandatory target arithmetic tests. Proposed model acceptance criteria, pending dataset-owner approval: held-out call-level split Pearson score correlation ≥0.80 to normalized MOS/PESQ-derived labels; fixed-versus-float score MAE ≤0.02, maximum error ≤0.10, correlation drop ≤0.02; alert false-positive ≤5% and false-negative ≤10% against declared degradation episodes and allowed response delay. These are team-proposed targets, not measured results or extra hackathon mandates. Define label normalization and minimum data volume before training. Report FP/FN denominators, confidence intervals, alert delay and per-scenario results. Synthetic data cannot prove these quality metrics.

## Candidate scaling risks and later validation boundary

Here “Q7” means seven fractional bits in signed8 storage, exactly **[−1.0, +0.9921875]**; it does not mean seven integer bits. Signed16 F12 covers [−8, 7.999755859375]. Signed32 F19 biases cover [−4096, 4096−2^−19]; signed40 F19 accumulators represent [−1048576, 1048576−2^−19]. Full signed24 F19 products cover [−16, 16−2^−19], although the legal operand product bound is tighter. Matrix products and biases align at F19; requantization shifts seven bits to F12. Elementwise products are F24 and shift twelve bits after the specified accumulation. No per-tensor zero point or arbitrary rescale is currently included.

Do not confuse the current artifact's **integer codes** with its **real-valued Q12 weights**. The stored384 prototype weights range −255…254;197 integer codes do not fit signed8 and may not be truncated/reinterpreted as INT8. Their old real values (code/4096, about −0.0623…0.0621) happen to fit the candidate F7 real range, but conversion would round code/32 and significantly reduce resolution. No conversion or new weight generation was performed. Future trained weights have unknown distributions and must be audited independently; fit of synthetic prototype real values proves nothing about QAT quality.

Phases 3–5 must characterize feature/weight/bias distributions, recurrent clipping, scale sensitivity, accumulator bounds, float-to-quantized score loss and task metrics. Compare legal fractional-bit alternatives while retaining INT8 weights/INT16 activations. Training must expose feedback requantization and the selected LUT behavior. PS-01 explicitly requires QAT; neither HW's PTQ nor QUANT's binary/ternary/quaternary experiments waive it. No trained weights or target accuracy results are claimed. Proposed error/quality thresholds above are review candidates; they must be declared and accepted before being used as quality pass criteria.
