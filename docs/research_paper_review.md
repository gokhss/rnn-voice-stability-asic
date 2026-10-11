# Research review — Phase 1, local papers

**Scope and authority.** PS-01 in [problem_statement.md](problem_statement.md) supplies requirements. Papers supply evidence for particular mathematical or engineering ideas; they do not replace PS-01. The architecture and numerical formats remain proposals, not implemented/trained/validated target results. All three requested papers are present locally and were read. No downloaded substitute was used. References below use 1-based PDF page numbers.

## Sources and provenance

| ID | Local source | Relevant scope |
|---|---|---|
| CHO | [Cho et al., Learning Phrase Representations using RNN Encoder–Decoder for Statistical Machine Translation](../1406.1078v3.pdf), arXiv 1406.1078v3, 3 September 2014, 15 PDF pages | Recurrent equations, gates, encoder/decoder distinctions; focus §§2.1–2.3 and Appendix A |
| HW | [Pacini, Rapuano, Tuttobene, Nannipieri, Fanucci, Moranti, Towards the Extension of FPG-AI Toolflow to RNN Deployment on FPGAs for On-board Satellite Applications](../Towards_the_Extension_of_FPG-AI_Toolflow_to_RNN_Deployment_on_FPGAs_for_On-board_Satellite_Applications.pdf), 5 PDF pages | Fixed-point deployment, resource reuse, controller/PE/activation organization, FPGA-specific case study |
| QUANT | [Alom, Moody, Maruyama, Van Essen, Taha, Effective Quantization Approaches for Recurrent Neural Networks](../Effective_Quantization_Approaches_for_Recurrent_Neural_Networks.pdf), IJCNN 2018, 8 PDF pages | Binary/ternary/quaternary training-time weight quantization and application-dependent accuracy |

PDF text was extracted with pdftotext; CHO pages 3 and 12 and QUANT page 3 were also rendered and visually inspected because mathematical layout matters. QUANT extraction/rendering emitted an xref reconstruction warning but returned success; its visible equation (13) was checked directly rather than inferred from incomplete extracted glyphs. The PDFs themselves remain unchanged. SHA-256 identities:

* `1406.1078v3.pdf`: `35acfcc574b37588ac0443ac65c9e2fccf794b24df9cf8522d6df5f09b82119c`
* `Towards_the_Extension_of_FPG-AI_Toolflow_to_RNN_Deployment_on_FPGAs_for_On-board_Satellite_Applications.pdf`: `a82bc0856fb875448262194707cab4f04a27671500e0b7a1262bc9fc4f14728e`
* `Effective_Quantization_Approaches_for_Recurrent_Neural_Networks.pdf`: `9937d772cb88cda26bcdb071cd7d8026c8a9e01659e2d7232ea93f179b6f925d`

## CHO: what the paper actually says

* **§2.1, page 2, equation (1):** recurrence updates a hidden vector from previous hidden vector and current input. Its optional sequence output in equations (2)–(3) is a probability distribution over symbols. That vocabulary softmax is not a voice stability output head.
* **§2.2, pages 2–3, equation (4):** the encoder reads an input sequence into context c; a decoder produces another sequence conditioned on c and prior outputs, with joint conditional log-likelihood training. PS-01 uses one recurrent layer operating continuously; it does not require this paired translation system, word embeddings, an end-of-sequence token, or translation loss.
* **§2.3, page 3, equation (5):** reset r = sigmoid(W_r x + U_r h_old). Equation (6) defines z = sigmoid(W_z x + U_z h_old). Both gates read the complete previous state.
* **Equation (7):** h_new = z ⊙ h_old + (1−z) ⊙ h_tilde. Thus z near one preserves state; z near zero selects candidate. Descriptive names alone cannot establish this polarity.
* **Equation (8):** h_tilde = phi(W x + U(r ⊙ h_old)). Reset is applied to the vector before the recurrent matrix multiply. The main equation uses a generic phi, not an explicit tanh symbol. §4.1.1, page 6 and Appendix A.1, page 12 explicitly choose tanh.
* **Appendix A.1 encoder, page 12:** repeats reset-before and the same z polarity, explicitly says biases are omitted for notational clarity, and fixes the encoder's initial h to zero. Our bias-enabled baseline is consistent with that statement; one explicit combined bias per gate is an engineering/export choice.

### Important distinctions within the primary paper

Appendix A.1.1 **decoder**, page 12, prints a different candidate organization: its reset component r'_j multiplies the j-th component of U' h'_old + Cc, after the recurrent transform. It also initializes h'_0 from context and includes context in its gates. Do not describe every formula in the paper as reset-before. Our selected baseline follows **main equations (5)–(8) and Appendix A.1 encoder**, not the context-conditioned decoder. U(r⊙h) and r⊙(Uh) are generally different because the diagonal reset matrix does not commute with U.

The main experiment discussion (§4.1.1, pages 5–6) describes rank-100 factorization/embeddings, while Appendix A.1 discusses a 500-dimensional embedding. These are paper-specific architecture details; neither is imported into PS-01 or silently reconciled into a requirement. Its 1000-hidden-unit translation experiments likewise do not mandate our 8/16 baseline. No claim about voice-quality accuracy, INT8/Q12 scaling, telecom IO, clock frequency, EMA, IRQ, ASIC area or milliwatt power follows from CHO.

## HW: useful hardware guidance, not an ASIC result

§III-A, page 2 describes uniform symmetric post-training quantization, power-of-two LSB relationships and feedback/pointwise truncation. §III-B, page 3 and Figures 3–4 describe a control unit, **two PEs** for gates that can execute concurrently, activation and saturation blocks, and pointwise arithmetic, with resources reused across dependent gate stages. ACT uses piecewise-linear approximations. These support explicit scheduling, recurrent scaling analysis and measuring reuse trade-offs; they do not show that exactly one scalar MAC is universally optimal.

Our one scalar multiplier is a more serialized PS-01 baseline, justified by our operation count and <1 ms budget. It differs from the paper's two-PE architecture. Our nearest/ties-away rounding and symmetric direct ROMs also differ from its truncation/PWL choices. Those choices require local numerical and PPA validation. A PE may contain substantial parallel arithmetic; “two PEs” must not be equated to two scalar multipliers. The paper reports hundreds of FPGA DSP resources in Table II, page 4.

Its §IV/Tables I–III, pages 3–4 concern satellite housekeeping forecasting, specific quantized models and a Kintex UltraScale device versus Jetson Nano. Their accuracy, inference time, FPGA resource counts and watt-scale power are results reported by those authors for those platforms, not PS-01 measurements or ASIC projections. No technology-independent conversion to low-milliwatt ASIC power is justified. Its claim about reuse preserving throughput is scoped to its schedule/dependencies, not a general theorem for every GRU architecture. PS-01 explicitly requires QAT; this paper's PTQ is not permission to substitute PTQ without owner clarification.

## QUANT: useful experimental method, different precision and gate polarity

§III, pages 4–5 discusses quantizing weights during forward propagation while updating full-precision weights using gradients, and choosing thresholds from weight statistics. Binary {−1,+1}, ternary {−1,0,+1}, and quaternary {−1,−0.5,+0.5,+1} values are examined. §IV, pages 5–7 evaluates recurrent models on addition/sentiment and moving-MNIST tasks. The legitimate lesson is to validate task-dependent quantization loss against floating baselines, not to assume lossless compression.

Its §II-B, page 3, equation (13) prints **h_new=(1−z)⊙h_old+z⊙h_tilde**, the opposite z polarity from CHO equation (7). Equations (10)–(12) also concatenate **[h_old,x]**, whereas this project's export concatenates **[x,h_old]** (or [x,q] for candidate). Blind weight reuse would mix both gate polarity and column order. A conversion would require explicit transformations and equivalence tests; it is not performed here. QUANT is used as quantization research, not the authority for our GRU convention.

This is not a validation of signed INT8 F7 weights with INT16 F12 state, our LUT errors, our feature data, or our target accuracy. Its low-bit value sets include +1, which is not representable by signed INT8 F7. We retain PS-01's precision requirements and defer QAT/export experiments to Phase 4. The cited but separately unsupplied PTQ paper in HW reference [12] has not been read and is not claimed as an additional reviewed source.

## Evidence boundary and remaining questions

| Classification | What belongs here |
|---|---|
| Paper facts | recurrence placement/polarity; explicit tanh and omitted biases in encoder; HW reuse/PE organization; QUANT training-time quantization and reversed z convention |
| PS-01 requirements | GRU preference, dimensions/ranges, INT8/INT16/QAT, recurring frame input, retained/flushed state, score/EMA/hysteresis/IRQ, low area/power and verification |
| Engineering decisions | explicit three gate biases plus head bias, row-major z/r/n order, 8/16 baseline, learned sigmoid head, EMA K, interface/register map and one-MAC baseline |
| Assumptions/estimates | 10 MHz candidate, fixed read latency, candidate F7/F12/F19 formats, ROM error bounds and 1547/5387-cycle budgets |
| Open validation | dataset/quality target, weight ranges and QAT loss, ROM/PWL trade-off, mapped memory/multiplier cost, PDK/clock/voltage and actual power |

The [mathematical specification](gru_mathematical_specification.md) is the project contract; numerical and hardware contracts are linked there. Only Phase 0 and Phase 1 are authorized. Next proposed phase is **Phase 2: floating-point model and its unit tests only**, and requires explicit owner approval.
