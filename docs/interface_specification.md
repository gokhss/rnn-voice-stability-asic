# Interface specification

## Authority, evidence and phase boundary

PS-01 in [problem_statement.md](problem_statement.md) is authoritative. [Research review](research_paper_review.md) identifies the paper-supported recurrence and research limitations; [mathematical specification](gru_mathematical_specification.md) fixes the project's bias-enabled reset-before equations. Unless attributed to a paper or PS-01, choices here are engineering proposals. Numeric formats, memory timing, clock and resource assumptions require later validation; open questions are tracked in [architecture decisions](architecture_decisions.md). Only Phase 0/1 are authorized now. Approval of the next phase authorizes **Phase 2 floating-point model and unit tests only**, not RTL, quantization or training. The prior implementation_roadmap.md is background, not phase authorization; the current numbered gates are in [architecture review](architecture_review.md).

Proposed future interface; no current RTL compatibility claim. Single rising-edge clock domain, synchronous active-low rst_n. External CDC adapters are integration responsibilities. I and H are elaboration parameters, not runtime controls.

## Feature and result ports

| Port | Direction / width | Contract |
|---|---|---|
| clk, rst_n | input, 1 each | synchronous reset; assert across a rising edge |
| s_axis_tdata | input, 16*I | one complete packed frame per beat; lane j bits 16j+:16 is signed Q12 |
| s_axis_tvalid | input, 1 | producer offers frame independently of ready |
| s_axis_tready | output, 1 | reset released, enabled, model valid, idle, no pending flush |
| frame_done | output, 1 | one-cycle successful completion, score/average/alert published together |
| score_out, average_out | output, 16 each | unsigned F16 holding registers; meaningful after first completion |
| alert, busy, irq | output, 1 each | alert is latched; busy covers execution/drain/flush; IRQ is masked sticky events |
| cfg_valid, cfg_write | input, 1 each | local synchronous register request; write=0 reads |
| cfg_addr | input, 8 | byte address, naturally 32-bit aligned |
| cfg_wdata | input, 32 | full-word writes only |
| cfg_ready, cfg_error | output, 1 each | combinational response to current request; cfg_ready=1 outside reset |
| cfg_rdata | output, 32 | combinational read before transfer edge; zero for WO/unmapped |

Transfers occur only at valid&&ready on a rising edge. Producer must hold data and valid until transfer; data after acceptance may change. No input queue, partial frame, TLAST, TKEEP, TSTRB, TID or TDEST. Every byte is valid and each beat is an independent frame. This is an AXI-Stream-compatible full-width, ready/valid subset for directly connected synchronous endpoints, not an AXI memory-mapped slave and not a serial AXI packet assembler. Integrations requiring those optional signals or a different width need a wrapper. No output backpressure: ports hold the most recent result; software must service faster than completion if every result is needed. Input stalls cannot overwrite the latched frame.

Local register bus is intentionally not called AXI-Lite or APB. There are no outstanding transactions, byte strobes or bursts. A bridge is external if the SoC uses those protocols. cfg_error is sampled with transfer; invalid access has no requested state change, sets ERROR sticky event. Requests held across multiple ready edges are multiple transactions.

## Register map

All registers 32 bits; reserved read bits zero, reserved write bits must zero or error. RO writes and WO reads error. Reset values below are literal integers/hex. All result reads during a frame return the last completed frame. IRQ event bits: 0 DONE, 1 DEGRADE (alert 0→1), 2 RECOVER (1→0), 3 FLUSH_DONE, 4 ERROR, 5 SAT. STATUS dynamic bits: 0 BUSY, 1 READY, 2 MODEL_VALID, 3 AVG_VALID, 4 ALERT, 5 FLUSH_PENDING; bits 6…31 zero.

| Address | Name | Access | Reset | Fields / side effects |
|---|---|---|---|---|
| 0x00 | CONTROL | RW | 0 | bit0 ENABLE; other bits zero. Disabling stops admission, accepted work drains |
| 0x04 | COMMAND | WO | 0 | one-hot: bit0 FLUSH, bit1 LOAD_BEGIN, bit2 LOAD_COMMIT; zero is no-op |
| 0x08 | STATUS | RO | 0 | dynamic bits above (READY also depends on reset/config) |
| 0x0c | THRESHOLDS | RW | 0x99998000 | low16 ASSERT=0.5, high16 RECOVER≈0.6; atomic pair, require recover>assert |
| 0x10 | EMA_SHIFT | RW | 4 | bits3:0 K=0…8; time constant about 16 frames at K=4 |
| 0x14 | SCORE | RO | 0 | low16 latest score |
| 0x18 | AVERAGE | RO | 0 | low16 latest average |
| 0x1c | IRQ_ENABLE | RW | 0 | low6 event masks |
| 0x20 | IRQ_STATUS | RW1C | 0 | low6 sticky events; write one clears; simultaneous event wins |
| 0x24 | FRAME_COUNT | RO | 0 | successful publications modulo 2^32, reset/flush clears |
| 0x28 | LOAD_INDEX | RO | 0 | next logical image word index; software cannot skip entries |
| 0x2c | LOAD_DATA | WO | 0 | one coefficient/bias per full bus word; advances index only on valid write |
| 0x30 | MODEL_ID | RW | 0 | software identifier set only while loading; read identifies current/load image |
| 0x34 | DIMENSIONS | RO | (H<<16) OR I | low16 I, high16 H; baseline 0x00100008 |
| 0x38 | IMAGE_WORDS | RO | 3H(I+H)+H+3H+1 | baseline 1217 words (logical transfer count, not stored bytes) |

Threshold/EMA writes require ENABLE=0, BUSY=0, FLUSH_PENDING=0. Invalid thresholds or shift reject the complete write, retain prior valid configuration, and set ERROR; never silently clamp. Threshold changes take effect on the next completed frame, with no immediate alert event. EMA shift changes preserve its history. To start fresh, issue FLUSH. ENABLE and IRQ accesses are legal while busy. Setting ENABLE when no valid model is rejected. Model writes/commands require disabled/idle/no pending flush; command collision or FLUSH while LOAD_ACTIVE errors. LOAD_ACTIVE is inferred by software from a successful LOAD_BEGIN until commit/reset (an extra public status bit is unnecessary). Repeated FLUSH while pending errors.

## Model loading

Runtime loading satisfies the repository's explicit weight-loading requirement; no untrained ROM is a valid production default. Physical storage: M=3H(I+H)+H signed 8-bit weights (baseline 1168 bytes), B=3H+1 signed 32-bit biases (196 bytes), total 1364 bytes. Coefficient memory is single-ported during compute; loading and execution are exclusive. Bias memory is separate. At maximum dimensions this is 5028 bytes.

LOAD_BEGIN invalidates model, sets index=0, enters load mode, and clears recurrent/per-call history exactly as flush, without emitting FLUSH_DONE. It retains thresholds, EMA setting, IRQ configuration and prior sticky events. LOAD_DATA indices 0…M−1 contain sign-extended signed 8-bit in the full 32-bit word (upper24 must copy bit7); subsequent B words are signed 32-bit biases. Invalid sign extension or out-of-range index rejects write and does not increment. Ordering is z/r/n rows with input then recurrent columns, output weights, z/r/n biases, output bias, as defined in scheduling. Sequential-only writes guarantee complete coverage without a large bitmap. LOAD_COMMIT requires precisely M+B valid writes; sets MODEL_VALID, leaves disabled, exits load mode. Incomplete commit errors and remains loading. Readback/CRC is not included; software should validate the exported image hash and MODEL_ID before loading, and directed loader tests must prove storage mapping. Model-valid means structurally loaded, not trained or quality validated.

Reset clears MODEL_VALID and loading metadata but need not reset coefficient RAM contents; invalid storage is inaccessible to compute. Flush preserves a committed model. A new load cannot preserve old recurrent state, because a model switch changes recurrence semantics.

## Flush, reset and priority

FLUSH is a call boundary command available enabled or disabled, idle or busy (except during loading). Register acceptance sets FLUSH_PENDING. Its effect occurs at the **following** rising edge. TREADY is low while pending. On the request edge an already offered frame may be accepted or an old frame may complete normally; software must not send the new call until FLUSH_DONE is observed. The next edge aborts any outstanding old-call operation, clears h and scratch valids, average-valid/history, score/result registers, alert and FRAME_COUNT, then sets FLUSH_DONE and clears pending. No successful DONE or score is emitted for aborted work. Prior sticky events are preserved so software can acknowledge them; flush itself does not create DEGRADE/RECOVER events.

Sequential priority: reset > pending flush > normal execution/publication > idle admission. Pending flush wins over a would-be completion and suppresses its DONE/alert/SAT events. Reset clears all registers, hidden/scratch validity, pending commands, output strobes, alert, counters and interrupt status/masks, aborts work and invalidates model. Reset has no completion IRQ. Recurrent bank and per-call registers are cleared in a single edge; physical implementation may use flip-flops for the small banks. Busy has no admission/completion overlap: even on publication and drain edges TREADY remains low. Disabling and flush requests accepted on an edge affect subsequent admission; do not retroactively invalidate a valid&&ready transfer on that edge.

Interrupt equation: irq = |(IRQ_STATUS & IRQ_ENABLE). It is level-sensitive until W1C, not a one-cycle pulse. Events latch even masked. DONE coalesces if software does not clear it between frames; FRAME_COUNT detects multiple completions (modulo wrap). DEGRADE is asserted only when a completed updated average is below assert threshold and previous alert=0. RECOVER only when average exceeds recover threshold and previous alert=1. Inside the band or on equality, hold alert. First average initializes from score then evaluates alert. SAT records arithmetic saturation on a normally completed frame; abort discards per-frame saturation. Error responses latch ERROR even when interrupts are disabled. W1C event-set wins; reset wins over both.

## Requirement interpretation and open integration points

The local PS-01 wording is “window/averaging configuration”; the current owner summary also says “window length.” Since both explicitly allow shift-based EMA, register 0x10 is the averaging-control register for this selected mode. K controls an exponential response, not an exact finite N-sample window; no misleading WINDOW_LENGTH alias is added. If the owner intends a separately programmable finite window despite the EMA option, clarify that before changing the design. A divider-free fixed/power-of-two window is an alternative, not silently implemented here.

All ports, register addresses/defaults, load protocol, flush timing and IRQ clear behavior are project engineering choices satisfying PS-01 control needs, not CHO instructions. The feature width, bus bridge, reset integration and whether a future system needs an output FIFO remain integration confirmations. Weight read timing is an analytical schedule assumption. The mathematical reset operation and h_0 definition are in gru_mathematical_specification.md; software waits for fresh FLUSH_DONE (clearing any earlier sticky FLUSH_DONE before issuing a new request) before sending a new call.
