# GRU mathematical specification — Phase 1 approval candidate

**Status:** mathematical contract reviewed against the local CHO paper; no new model, training, quantization code, RTL or testbench is implemented. PS-01 is authoritative for the application and constraints. [Research review](research_paper_review.md) distinguishes paper facts from project choices and documents the decoder/secondary-paper convention differences. This file governs the future Phase 2 floating model; [numerical specification](numerical_specification.md) defines the candidate later integer realization, not floating semantics.

## Dimensions and orientation

Use column vectors and zero-based array indices. One layer and one call context. Engineering baseline I=8 inputs, H=16 hidden values, one output; support any elaboration/model configuration I=8…16, H=16…32. These ranges come from PS-01; the specific baseline is our smallest legal design choice, not a CHO experiment configuration.

| Quantity | Shape | Meaning |
|---|---|---|
| x_t | I×1 | normalized feature frame; normalization remains data-dependent |
| h_old, h_t, n_t, r_t, z_t, q_t | H×1 | old/new state, candidate, reset/update gates and reset product |
| W_r, W_z, W_n | H×I each | input-to-gate matrices; output-neuron rows, input-feature columns |
| U_r, U_z, U_n | H×H each | recurrent matrices; destination-neuron rows, source-state columns |
| b_r, b_z, b_n | H×1 each | independent trainable combined gate biases |
| W_s | 1×H | learned score-head row vector (v in hardware docs) |
| b_s, s_t, p_t | scalar | learned head bias, logit, normalized score (b_out in hardware docs) |

Every matrix-vector multiply means y[j]=sum_k M[j,k]*v[k]; vectors are never multiplied on the left and exported matrices are not implicitly transposed. Distinguish neuron j from recurrent source k. W_n/U_n correspond to CHO's W/U; n_t is its h_tilde. Parameter count = 3HI + 3H² + 3H + H + 1 = 3H(I+H)+4H+1, or 1217 baseline / 4737 maximum. Exactly 3H+1 of those parameters are biases. No decoder context, second recurrent layer, LSTM cell state, word embedding or vocabulary output is included.

## Chosen floating-point recurrence

Let sigmoid(a)=1/(1+exp(−a)), with all activations elementwise:

```
r_t = sigmoid(W_r x_t + U_r h_old + b_r)
z_t = sigmoid(W_z x_t + U_z h_old + b_z)
q_t = r_t ⊙ h_old
n_t = tanh(W_n x_t + U_n q_t + b_n)
h_t = z_t ⊙ h_old + (1 − z_t) ⊙ n_t
```

Reset-before and update polarity follow CHO main equations (5)–(8), PDF page 3, and Appendix A.1 encoder, page 12. Main equation (8) uses phi; tanh is explicit in Appendix A.1 and §4.1.1. Appendix A says biases are omitted for clarity, so using trainable biases is consistent; choosing **one combined bias vector per gate, outside the reset product**, is our explicit parameterization. There is no separately reset recurrent bias. If a later training framework stores two compatible additive biases, combine them only after checking their placement; a reset-after recurrent bias cannot be merged by assumption.

**Reset-before means** n[j]=tanh(b_n[j]+sum_i W_n[j,i]x[i]+sum_k U_n[j,k]r[k]h_old[k]). It does not mean r[j]*sum_k U_n[j,k]h_old[k]. For a two-component subspace with U=[[0,1],[1,0]], h=[1,1] and r=[1,0], U(r⊙h)=[0,1] while r⊙(Uh)=[1,0]; this gives a concrete future variant-discrimination test. **Update means** z=1 preserves old state, z=0 chooses candidate. These are limiting-value checks, not claims that the finite sigmoid table outputs exactly both endpoints. Floating tests may directly probe the blend inputs or use large gate logits with stated tolerance.

Conceptual equations list r then z to match CHO's numbering; storage and hardware computation order is **z, r, n**. z and r have no interdependence and both read immutable h_old, so computing all z first is equivalent. Then compute all q, all n, all h_next and atomically commit. Never update h_old neuron-by-neuron during gate calculation. Floating Phase 2 must use true sigmoid/tanh and real-valued products; quantized q rounding is reserved for the later integer model.

## Initial conditions, calls and streaming

h_0 is the all-zero H-vector. Zero initialization matches CHO's encoder and is selected for each new PS-01 call. Successful frames persist h_t into the next frame; idle gaps and deasserted input valid do not update it. No automatic frame-count or time-based reset. A mathematical `flush` begins a new call with zero h, uninitialized average and cleared alert. The hardware request/acknowledgement can abort work and is separately defined by [interface specification](interface_specification.md): accepted flush command sets pending, the following edge clears state, and new-call input waits for FLUSH_DONE. Flushed/aborted frames produce no successful public result. Reset also invalidates loaded model, while flush preserves it. Disabling admission alone must not clear state or cancel an already accepted operation.

## PS-01 output head (not from the translation paper)

```
s_t = W_s h_t + b_s
p_t = sigmoid(s_t)
```

The head consumes the fully updated state. In real arithmetic 0<p_t<1 for finite s_t; normalized hardware codes remain within [0,1]. A high score means better quality by chosen label convention. For normalized MOS/PESQ regression, p is a bounded quality estimate, **not automatically a calibrated probability**. If future labels instead encode a binary stability event, interpretation and loss must be declared explicitly. Training/evaluation, data split and reference quality metric establish meaning; an untrained sigmoid output is not evidence of voice monitoring accuracy. Label choice and metric calibration belong to Phase 3, not this mathematical implementation phase.

## PS-01 average, hysteresis and interrupt

Real-valued ideal EMA: alpha=2^(−K), K∈{0,…,8}, default K=4; first score initializes A=p, later A←A+alpha(p−A). No average update during idle. The candidate integer realization uses score P and average A in unsigned16 F16, signed18 difference, nearest/ties-away `R` and explicit unsigned saturation:

```
first completed score: A = P; initialized = true
otherwise:            A = usat16(A + R(signed(P) − signed(A), K))
```

P=min(65535, sigmoid_q12(s_t)<<4); this transport has only Q12-derived score resolution. R(v,0)=v; R(v,K)=sign(v)*floor((abs(v)+2^(K−1))/2^K) otherwise, implemented with shifts. Candidate scaling/range/deadband and saturation rules are detailed once in [numerical specification](numerical_specification.md). Configuration changes preserve history and affect the next frame; flush clears history.

Let L be assertion threshold and U recovery threshold, with 0≤L<U≤65535. On each newly completed average: if alert=0 and A<L, set alert; if alert=1 and A>U, clear it; otherwise hold it, including equality. Invalid threshold pairs are rejected atomically with error status; no silent swap or clamp. A clear-to-set alert event latches DEGRADE status regardless of masking; `irq=OR(IRQ_STATUS & IRQ_ENABLE)`, held until software W1C. A simultaneous new event wins over W1C; reset clears events, and flush clears alert but preserves earlier sticky events. DONE/RECOVER/FLUSH_DONE/ERROR/SAT are additional project events defined in the register map. None of the EMA, hysteresis or interrupt behavior is prescribed by CHO.

## Export identity and memory order

Gate IDs: 0=z, 1=r, 2=n. For each gate g, for destination j increasing, export row [W_g[j,0…I−1], U_g[j,0…H−1]]. Flattened weight index=(gH+j)(I+H)+t. Export W_s[0…H−1] next. Bias stream follows all weights: b_z, b_r, b_n, then b_s. For the candidate the recurrent columns multiply q, not raw old h. Index zero is the least-significant lane in packed vectors. Load signed INT8 coefficient values in sign-extended bus words; mathematical weights remain floating values until Phase 4 export. Metadata must explicitly state dimensions, gate order, reset-before, z-preserves-old polarity, bias placement and normalization/scales.

An imported model using [h,x] column order, reversed z polarity, reset-after placement or transposed matrices is incompatible until an explicit conversion is proved. No existing research/model file is silently treated as ready-to-load weights.

## Phase 2 acceptance requirements (planned only)

After approval, implement only the floating reference and unit tests: shape validation for legal dimensions; zero state/zero weights; explicit bias effects; per-neuron matrix orientation; z blend polarity; reset-before versus reset-after discriminator with non-diagonal U; independent scalar-loop versus vectorized recurrence; persistent frames versus flushed calls; head uses new state; output bounds; deterministic input/parameter fixtures and reproducible test commands. No trained or quantized model is required to test those mathematical properties. Tolerances/dtype must be specified in Phase 2 and are not the later bit-exact integer tolerance. Future phases remain separately gated.
