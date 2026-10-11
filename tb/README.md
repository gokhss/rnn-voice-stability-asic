# Regression

Run from repository root with `make test`. `make model` executes independent
Python integer checks and regenerates the 128-frame oracle. `make sim` compiles
and runs all three benches with Icarus; `SIM=verilator make sim` uses timed binary
simulation; `SIM=xrun make sim` uses Xcelium. Fatal checks and watchdogs return
failure, and VCDs go to waveforms/. Verilator and Xcelium paths are unvalidated
until those tools are available. CI installs Icarus and Verilator.

`test_vectors.mem`: 128 lines, 80 hexadecimal characters per line, MSB first:
input vector (128), expected hidden state (128), score (16), average (16),
threshold (16), window (8), alert (8). Within packed vectors neuron/feature zero
is the least-significant 16-bit lane. Exact bit equality is required; tolerance
is zero because the oracle models every quantization point.

Coverage: top tests reset and in-flight abort, valid/ready, disabled admission,
enable changing while busy, 128 stateful frames, invalid cycles, held-valid
backpressure, window changes and strict/equal threshold behavior. Cell compares
all hidden states, tests MAC rounding ties/saturation and exhaustively checks
activation approximations. Average tests circular wrap, startup, maximum scores,
invalid samples and minimum/maximum/clamped/reconfigured windows.

These are simulation checks, not formal proofs or code-coverage measurements.
A true continuously accepting upstream source must hold the next frame while
ready is low. The bench holds valid while busy and tests consecutive queued
transactions; acceptance spacing is bounded by the resource-shared engine.
