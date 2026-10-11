"""Phase 2 float64 reference: reset-before GRU, z preserves old state.

See docs/gru_mathematical_specification.md. Default parameters are UNTRAINED
functional-test fixtures, not a voice-quality predictor. No training, integer
arithmetic model, LUTs, EMA, or hardware control emulation is provided here.
"""

from numbers import Integral

import numpy as np


def _dimension(name, value, lower, upper):
    if isinstance(value, bool) or not isinstance(value, Integral):
        raise ValueError("{} must be an integer in [{}, {}]".format(name, lower, upper))
    if not lower <= value <= upper:
        raise ValueError("{} must be in [{}, {}]".format(name, lower, upper))
    return int(value)


def _array(name, value, shape):
    try:
        raw = np.asarray(value)
    except (TypeError, ValueError) as exc:
        raise ValueError("{} must be a real numeric array".format(name)) from exc
    if raw.dtype.kind not in "fiu":
        raise ValueError("{} must contain real numbers, not {}".format(name, raw.dtype))
    if raw.shape != shape:
        raise ValueError("{} shape must be {}, got {}".format(name, shape, raw.shape))
    with np.errstate(over="ignore", invalid="ignore"):
        result = np.array(raw, dtype=np.float64, copy=True)
    if not np.all(np.isfinite(result)):
        raise ValueError("{} must contain finite float64 values".format(name))
    return result


def _finite(name, value):
    if not np.all(np.isfinite(value)):
        raise ValueError("non-finite {} during GRU evaluation".format(name))
    return value


def _sigmoid(value):
    """True sigmoid evaluated without exp overflow; no clipping or LUT."""
    result = np.empty_like(value)
    positive = value >= 0
    result[positive] = 1.0 / (1.0 + np.exp(-value[positive]))
    negative_exp = np.exp(value[~positive])
    result[~positive] = negative_exp / (1.0 + negative_exp)
    return result


class GRUParameters:
    """Explicit freely configurable weights and biases, copied on entry/access.

    Shapes: W_g=(H,I), U_g=(H,H), b_g=(H,), W_s=(1,H), b_s=().
    Biases are model parameters, not hardwired constants. This inference-only
    class does not compute gradients or imply that supplied values are trained.
    """

    def __init__(self, inputs=8, hidden=16, **tensors):
        self._inputs = _dimension("inputs", inputs, 8, 16)
        self._hidden = _dimension("hidden", hidden, 16, 32)
        shapes = {}
        for gate in ("z", "r", "n"):
            shapes["W_" + gate] = (self.hidden, self.inputs)
            shapes["U_" + gate] = (self.hidden, self.hidden)
            shapes["b_" + gate] = (self.hidden,)
        shapes.update(W_s=(1, self.hidden), b_s=())
        missing, extra = set(shapes) - set(tensors), set(tensors) - set(shapes)
        if missing or extra:
            raise ValueError("parameter names: missing={}, extra={}".format(
                sorted(missing), sorted(extra)))
        self._tensors = {name: _array(name, tensors[name], shape)
                         for name, shape in shapes.items()}

    @property
    def inputs(self):
        return self._inputs

    @property
    def hidden(self):
        return self._hidden

    def as_dict(self):
        """Return independent float64 arrays, suitable for explicit replacement."""
        return {name: value.copy() for name, value in self._tensors.items()}

    @classmethod
    def untrained(cls, inputs=8, hidden=16, seed=0):
        """Deterministic UNTRAINED test parameters; no global RNG side effects.

        Local NumPy RandomState: weights uniform [-0.2,0.2), biases [-0.05,0.05).
        These ranges are test initialization choices, not quantization scales.
        """
        inputs = _dimension("inputs", inputs, 8, 16)
        hidden = _dimension("hidden", hidden, 16, 32)
        seed = _dimension("seed", seed, 0, 2**32 - 1)
        rng = np.random.RandomState(seed)
        values = {}
        for gate in ("z", "r", "n"):
            values["W_" + gate] = rng.uniform(-0.2, 0.2, (hidden, inputs))
            values["U_" + gate] = rng.uniform(-0.2, 0.2, (hidden, hidden))
            values["b_" + gate] = rng.uniform(-0.05, 0.05, hidden)
        values["W_s"] = rng.uniform(-0.2, 0.2, (1, hidden))
        values["b_s"] = rng.uniform(-0.05, 0.05)
        return cls(inputs, hidden, **values)


def evaluate_frame(parameters, features, hidden_state):
    """Pure single-frame equations, returning independent debugging values.

    NumPy vectors use (I,) and (H,) storage for the spec's column vectors.
    Broadcasting column/batch shapes is deliberately rejected. Neither caller
    inputs nor parameters are mutated. Non-finite arithmetic raises ValueError.
    """
    if not isinstance(parameters, GRUParameters):
        raise TypeError("parameters must be GRUParameters")
    x = _array("features", features, (parameters.inputs,))
    h = _array("hidden_state", hidden_state, (parameters.hidden,))
    w = parameters._tensors
    try:
        with np.errstate(over="raise", invalid="raise", divide="raise", under="ignore"):
            a_r = _finite("reset preactivation", w["W_r"] @ x + w["U_r"] @ h + w["b_r"])
            a_z = _finite("update preactivation", w["W_z"] @ x + w["U_z"] @ h + w["b_z"])
            r, z = _sigmoid(a_r), _sigmoid(a_z)
            q = r * h
            a_n = _finite("candidate preactivation", w["W_n"] @ x + w["U_n"] @ q + w["b_n"])
            n = np.tanh(a_n)
            h_new = _finite("hidden state", z * h + (1.0 - z) * n)
            s = _finite("score logit", w["W_s"] @ h_new + w["b_s"])
            p = float(_sigmoid(s)[0])
    except FloatingPointError as exc:
        raise ValueError("non-finite arithmetic during GRU evaluation") from exc
    return {"x": x, "h_old": h, "a_r": a_r, "a_z": a_z, "r": r,
            "z": z, "q": q, "a_n": a_n, "n": n, "h_new": h_new,
            "s": float(s[0]), "p": p}


class FloatGRU:
    """One-call stateful reference, initially h=0; call start_call() to flush.

    step() returns a Python float score. With debug=True, last_debug exposes
    the most recent gate/preactivation/state snapshot. No quality accuracy is
    implied by the default UNTRAINED parameters. No hardware timing is modeled.
    """

    def __init__(self, parameters=None, debug=False):
        if parameters is None:
            parameters = GRUParameters.untrained()
        if not isinstance(parameters, GRUParameters):
            raise TypeError("parameters must be GRUParameters")
        if not isinstance(debug, bool):
            raise ValueError("debug must be bool")
        self._parameters = GRUParameters(parameters.inputs, parameters.hidden,
                                         **parameters.as_dict())
        self._debug = debug
        self.start_call()

    @property
    def inputs(self):
        return self._parameters.inputs

    @property
    def hidden(self):
        return self._parameters.hidden

    @property
    def hidden_state(self):
        return self._state.copy()

    @property
    def last_debug(self):
        if self._last_debug is None:
            return None
        return {key: value.copy() if isinstance(value, np.ndarray) else value
                for key, value in self._last_debug.items()}

    def start_call(self):
        """Mathematical call flush: clear h/debug, retaining model parameters."""
        self._state = np.zeros(self.hidden, dtype=np.float64)
        self._last_debug = None

    def step(self, features):
        """Commit state only after successful evaluation of the entire frame."""
        trace = evaluate_frame(self._parameters, features, self._state)
        self._state = trace["h_new"].copy()
        self._last_debug = trace if self._debug else None
        return trace["p"]
