# Phase 2 — floating-point GRU reference and unit tests

Status: Phase 2 complete; stop before Phase 3. The owner provisionally approved
the Phase 1 mathematics and architecture and authorized only this floating-point
reference and its tests. The source of truth is
[gru_mathematical_specification.md](gru_mathematical_specification.md).
No training, quantization, LUT, RTL, EMA/alert or hardware-control implementation
is part of this change. Earlier phase documents remain preserved historical
records, including their statements that the floating reference was then absent.

## Files and recovery

New project files:

* [model/gru_float.py](../model/gru_float.py): float64 equations and one-call state.
* [tests/test_gru_float.py](../tests/test_gru_float.py): standard-library unittest
  suite and an independent scalar equation oracle.
* [docs/phase2_report.md](phase2_report.md): this usage and execution report.

Existing project files modified: **none**. Files deleted: **none**.
All 65 starting files were archived and SHA-256 verified before additions.
Git metadata remains unavailable, so no Git clean-tree or commit claim is made.
The checkpoint is at workspace-relative
`recovery/phase2-20261010T203753Z/`, outside the project. Its `repository.tar.gz`,
`manifest.json`, `CHECKPOINT.md` and `run_manifest.json` provide recovery
instructions, starting hashes, changed-file inventory and validation results.
The final comparison confirms all 65 existing files remain byte-identical,
including RTL, existing SV testbenches and fixtures, generated weights, existing
Python models/quantization, configuration, synthesis and physical-design scripts.

## Equations, dimensions and parameter semantics

The model implements exactly:

```
r = sigmoid(W_r @ x + U_r @ h_old + b_r)
z = sigmoid(W_z @ x + U_z @ h_old + b_z)
q = r * h_old
n = tanh(W_n @ x + U_n @ q + b_n)
h_new = z * h_old + (1 - z) * n
s = W_s @ h_new + b_s
p = sigmoid(s)
```

`*` here is elementwise. Reset is before the recurrent candidate transform;
the candidate bias is outside the reset product. z weights old state, not the
candidate. The scalar output head uses the fully updated hidden state. The
implementation neither imports nor alters the old fixed-point `gru_reference.py`.

Default I=8, H=16; all integer I in 8…16 and H in 16…32 are accepted. Matrices
use destination-neuron rows: W_g `(H,I)`, U_g `(H,H)`, b_g `(H,)`, W_s `(1,H)`
and b_s scalar `()`. NumPy `(I,)`/`(H,)` vectors represent the specification's
column vectors. Batched `(1,I)` and explicit `(I,1)` arrays are rejected rather
than silently broadcast. No model export or memory-image generation is added.

All 11 weight/bias tensors are independently configurable parameters; the three
gate biases and head bias are not hardwired. They are the parameters that a
future authorized training phase may learn. This NumPy inference reference has
no gradients, optimizer or training loop and makes no assertion that supplied
parameters are trained. Parameters are copied on construction and through
`as_dict()`. To change values explicitly, create a new `GRUParameters` and model;
there is no implicit mid-call weight reload.

Default/test initialization uses a local NumPy `RandomState(seed)` with weights
uniform in [-0.2,0.2) and biases in [-0.05,0.05), in z/r/n then head order.
The default seed is zero; valid seeds are integers 0…2^32−1. This is deterministic
**untrained test initialization**, not a trained checkpoint or a quantization
range. It does not modify NumPy's global RNG. Reproducibility was tested in the
reported environment; no cross-platform bit-identical floating BLAS promise is
made.

## API and reproducible usage

Run from `rnn-voice-stability-asic/`:

```
python3 -B -m unittest discover -s tests -v
```

The `-B` flag avoids bytecode artifacts in the existing project tree. Do not run
`make model` or `make test` for these tests: those existing targets regenerate
the old fixed-point fixtures and are outside this phase's change scope.

Example, using only synthetic untrained parameters:

```python
import numpy as np
from model.gru_float import FloatGRU, GRUParameters, evaluate_frame

parameters = GRUParameters.untrained(inputs=8, hidden=16, seed=7)
model = FloatGRU(parameters, debug=True)
score_1 = model.step(np.zeros(8, dtype=np.float64))
score_2 = model.step(np.ones(8, dtype=np.float64) * 0.1)
trace = model.last_debug
model.start_call()  # zero hidden state; retain parameter values

# Pure equation evaluation with an explicitly supplied state, no model mutation:
frame = evaluate_frame(parameters, np.zeros(8), np.zeros(16))
```

`FloatGRU()` creates the default untrained 8/16 model. `step(features)` returns
a Python float score and commits hidden state only after the full frame succeeds.
`hidden_state` returns a copy. `start_call()` clears hidden state and the last
debug snapshot; repeating a call with the same inputs/parameters reproduces the
same results. There is no automatic state reset between frames. Hardware flush
request/acknowledgement timing, EMA, alerts and IRQs are not simulated here.

With `debug=True`, `last_debug` returns independent copies of `x`, `h_old`,
`a_r`, `a_z`, `r`, `z`, `q`, `a_n`, `n`, `h_new`, and scalar `s`, `p`.
With debugging disabled, `last_debug` is None; the equations and scores are
unchanged. A failed frame preserves both the previous state and debug snapshot.
`evaluate_frame` always returns these intermediates without updating any state.

## Floating arithmetic and errors

All inference arithmetic uses NumPy float64 and true exponential/tanh functions.
The sigmoid evaluates positive and negative arguments separately to avoid
exponential overflow, without clipping, fixed-point saturation or a LUT.
IEEE floating-point rounding/underflow can yield exactly 0 or 1 at extreme
logits; this is not a mathematical claim of finite-logit sigmoid endpoints.
Benign exponential underflow is allowed. Inputs, state and parameters must be
finite real numeric values; integral-valued arrays are converted to float64,
not treated as encoded fixed-point values. Boolean, string, object and complex
arrays are rejected. Features are not normalized or clipped automatically.

Bad dimensions, names, shapes, values or seed/debug settings raise descriptive
ValueError exceptions. Wrong parameter-object types raise TypeError. Finite inputs
that cause non-finite intermediate arithmetic raise ValueError before committing
state. Parameter shape and orientation errors are not automatically transposed.

## Checks executed and actual results

Environment checked: Python **3.10.12**, NumPy **2.2.6**. pytest, PyTorch and
TensorFlow are not discoverable in the inspected interpreter. No dependency was
installed. The existing standard-library-only requirements file describes the
old model and was preserved; this new module additionally requires NumPy.
No particular untested minimum NumPy version is asserted.

The unittest command above ran **21 tests: all passed, no skips or failures**.
The suite covers:

| Check | Actual scope/result |
|---|---|
| Default and zero model | 8/16, float64, zero initial h, zero logits, gates 0.5, score 0.5: PASS |
| Explicit biases | reset, update, candidate and head bias effects: PASS |
| Reset-before discriminator | non-diagonal U and unequal r distinguish U(r*h) from r*(U*h), including outside-reset bias: PASS |
| Update-gate polarity | extreme positive/negative z logits preserve old state/select candidate: PASS |
| Output orientation/state | isolated feature-to-neuron path and head selecting updated neuron: PASS |
| All legal dimensions | all 9×17=153 I/H pairs; three frames each, every intermediate compared: PASS |
| Nonzero supplied state | 9/17 independently supplied old state against scalar equations: PASS |
| Consecutive frames | 256 frames at 16/32, every intermediate checked and score/state bounded: PASS |
| Persistence and new calls | continuity, zero state after start_call, identical replay/fresh-call results: PASS |
| Distinct input sequences | different frame ordering produces distinct output with fixed untrained parameters: PASS |
| Determinism and ownership | same seeds reproduce tensors, no global RNG side effects, copied inputs/parameters/debug/state: PASS |
| Validation/recovery | dimensions, seeds, missing/extra parameters, shapes, non-finite/non-real inputs, overflow and atomic failure behavior: PASS |
| Debug/normal equivalence | identical scores; debug does not change arithmetic or leak mutable state: PASS |

The equation oracle is independently written with Python component loops,
`math.fsum`, `math.tanh` and sigmoid's tanh identity. It does not call production
sigmoid/evaluation helpers or use matrix multiplication. Every preactivation,
gate, reset product, candidate, blend, head logit and score is compared with
`atol=1e-12, rtol=1e-12` for moderate finite test values. The main dimension sweep,
256-frame sequence and supplied-state probe total **716 frame-level oracle
comparisons**. Extreme-logit behavior is tested separately without relying on
the oracle's less well-conditioned tail identity. Directed variant tests guard
against both implementations sharing a polarity/reset-placement mistake.

These results establish tested floating mathematical behavior, not trained
voice-quality accuracy, bit-accurate fixed-point/RTL equivalence or PPA. This
256-frame test is not represented as the required one-hour system regression.
The old SV benches and implementation flows were not run in Phase 2.

## Remaining work and stop condition

No voice-quality dataset, trained weights, training targets, QAT, quantized
export, integer reference or target RTL was created. Data normalization, target
definition, call-level splits, model adequacy and accuracy criteria remain open.
The reference intentionally omits averaging, alert/control emulation and any
hardware scheduling: those are outside the authorized floating GRU/head task.

Recommended next phase is **Phase 3 only: dataset/target audit and training
pipeline**, when explicitly authorized. Suitable data and a target definition
must be established before claiming a useful learned predictor. No Phase 3 or
later work has started; wait for the owner's next explicit approval.
