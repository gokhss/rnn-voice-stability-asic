# PS-01 — RNN-Based Voice Stability Monitor

Design a low-power RTL accelerator that runs a small recurrent layer (GRU preferred; LSTM as an alternative) on per-frame voice-quality features and produces a running average stability score. The accelerator is intended for a telecom edge device, where it continuously monitors live calls and flags degraded voice quality in real time without offloading to a cloud service.

## Functional requirements

- Input: a feature vector every 10–20 ms, including jitter, packet-loss flag, energy, SNR estimate and selected spectral features; 8–16 features delivered over AXI-Stream.
- Recurrent core: one GRU or LSTM layer with 16–32 hidden units. INT8 weights and INT16 activations, with quantization-aware training.
- Compute: small time-multiplexed MAC array. Fully parallel implementations are discouraged; area and power are primary metrics.
- Nonlinearities: sigmoid and tanh by LUT or piecewise-linear approximation, with approximation error documented.
- State: hidden state retained across frames, with a flush command that clears state at the start of each call.
- Score: per-frame stability score in [0,1].
- Averaging: shift-based exponential moving average or configurable windowed average; no hardware dividers.
- Alerting: interrupt when the average falls below a programmable threshold, with hysteresis.
- Control: register map for enable, threshold, window/averaging configuration, status and weight loading. Clock gating when idle.

## Target specifications

- Per-frame latency: under 1 ms.
- Power: low-milliwatt range; report an estimated figure and method.
- Accuracy: score correlation with a reference quality metric (MOS/PESQ-derived) above a threshold declared by the team.
- Quantization loss: difference between floating-point model and RTL output reported and justified.

## Required verification

- Bit-accurate comparison between Python/NumPy golden model and RTL (cocotb or UVM).
- Error analysis for quantization and LUT approximation.
- Long-stream test equivalent to a one-hour call, with state continuity verified.
- Corner cases: reset mid-call, saturated inputs, back-to-back frames and a threshold crossing.

See [architecture.md](architecture.md) for the implementation contract and known prototype gaps.
