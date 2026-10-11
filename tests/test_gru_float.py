"""Phase 2 tests; all parameters/data are synthetic and UNTRAINED.

Run from project root: python3 -B -m unittest discover -s tests -v
The scalar oracle uses Python loops/math.fsum, not production helpers or @.
"""

import math
import unittest

import numpy as np

from model.gru_float import FloatGRU, GRUParameters, evaluate_frame


def zero_tensors(inputs=8, hidden=16):
    values = {}
    for gate in ("r", "z", "n"):
        values["W_" + gate] = np.zeros((hidden, inputs))
        values["U_" + gate] = np.zeros((hidden, hidden))
        values["b_" + gate] = np.zeros(hidden)
    values.update(W_s=np.zeros((1, hidden)), b_s=0.0)
    return values


def scalar_oracle(parameters, x, old):
    """Independent component equations in approved destination-row convention."""
    w = parameters.as_dict()

    def sigmoid(v):
        # Independent identity, adequately conditioned for the moderate oracle inputs.
        return (1.0 + math.tanh(v / 2.0)) / 2.0

    def affine(gate, recurrent):
        return [math.fsum(
            [float(w["b_" + gate][j])] +
            [float(w["W_" + gate][j, k]) * float(x[k])
             for k in range(parameters.inputs)] +
            [float(w["U_" + gate][j, k]) * float(recurrent[k])
             for k in range(parameters.hidden)])
            for j in range(parameters.hidden)]

    ar, az = affine("r", old), affine("z", old)
    r, z = [sigmoid(v) for v in ar], [sigmoid(v) for v in az]
    q = [r[k] * float(old[k]) for k in range(parameters.hidden)]
    an = affine("n", q)
    n = [math.tanh(v) for v in an]
    new = [z[k] * float(old[k]) + (1.0 - z[k]) * n[k]
           for k in range(parameters.hidden)]
    s = math.fsum([float(w["b_s"])] +
                  [float(w["W_s"][0, k]) * new[k] for k in range(parameters.hidden)])
    return dict(a_r=ar, a_z=az, r=r, z=z, q=q, a_n=an, n=n,
                h_old=old, h_new=new, s=s, p=sigmoid(s))


class FloatGRUTests(unittest.TestCase):
    def assert_trace(self, actual, expected):
        for name, value in expected.items():
            np.testing.assert_allclose(actual[name], value, atol=1e-12, rtol=1e-12,
                                       err_msg=name)

    def test_default_dimensions_dtype_and_zero_initial_state(self):
        model = FloatGRU()
        self.assertEqual((model.inputs, model.hidden), (8, 16))
        self.assertEqual(model.hidden_state.dtype, np.float64)
        np.testing.assert_array_equal(model.hidden_state, np.zeros(16))
        self.assertIsNone(model.last_debug)
        self.assertIsInstance(model.step(np.zeros(8)), float)
        self.assertIsNone(model.last_debug)

    def test_zero_parameters_equations(self):
        params = GRUParameters(**zero_tensors())
        trace = evaluate_frame(params, np.zeros(8), np.zeros(16))
        for name in ("a_r", "a_z", "a_n", "q", "n", "h_new"):
            np.testing.assert_array_equal(trace[name], np.zeros(16))
        for name in ("r", "z"):
            np.testing.assert_array_equal(trace[name], np.full(16, 0.5))
        self.assertEqual(trace["s"], 0.0)
        self.assertEqual(trace["p"], 0.5)

    def test_all_biases_are_explicit_parameters(self):
        values = zero_tensors()
        values.update(b_r=np.full(16, math.log(3.0)),
                      b_z=np.full(16, -math.log(3.0)),
                      b_n=np.full(16, 0.4), b_s=math.log(3.0))
        trace = evaluate_frame(GRUParameters(**values), np.zeros(8), np.full(16, 0.2))
        np.testing.assert_allclose(trace["r"], 0.75)
        np.testing.assert_allclose(trace["z"], 0.25)
        np.testing.assert_allclose(trace["n"], math.tanh(0.4))
        np.testing.assert_allclose(trace["h_new"], 0.25 * 0.2 + 0.75 * math.tanh(0.4))
        self.assertAlmostEqual(trace["p"], 0.75)

    def test_reset_before_non_diagonal_matrix_and_bias_placement(self):
        values = zero_tensors()
        values["U_n"][0, 1] = values["U_n"][1, 0] = 1.0
        values["b_r"][:2] = [math.log(4.0), -math.log(4.0)]
        values["b_n"][:2] = [0.1, -0.1]
        old = np.zeros(16)
        old[:2] = [0.5, -0.25]
        trace = evaluate_frame(GRUParameters(**values), np.zeros(8), old)
        np.testing.assert_allclose(trace["q"][:2], [0.4, -0.05])
        np.testing.assert_allclose(trace["a_n"][:2], [0.05, 0.3], atol=1e-14)
        np.testing.assert_allclose(trace["n"][:2], [math.tanh(0.05), math.tanh(0.3)])
        reset_after = trace["r"] * (values["U_n"] @ old) + values["b_n"]
        self.assertGreater(np.max(np.abs(trace["a_n"] - reset_after)), 0.1)

    def test_update_gate_preserves_old_state_not_candidate(self):
        old = np.linspace(-0.8, 0.8, 16)
        values = zero_tensors()
        values["b_n"][:] = 0.3
        for logit, expected in [(1000.0, old), (-1000.0, np.full(16, math.tanh(0.3)))]:
            with self.subTest(logit=logit):
                values["b_z"][:] = logit
                trace = evaluate_frame(GRUParameters(**values), np.zeros(8), old)
                np.testing.assert_allclose(trace["h_new"], expected, atol=1e-15)

    def test_output_head_uses_updated_state_and_row_orientation(self):
        values = zero_tensors()
        values["W_n"][3, 2] = 0.75
        values["W_s"][0, 3] = 2.0
        values["b_s"] = 0.2
        x = np.zeros(8)
        x[2] = 0.4
        trace = evaluate_frame(GRUParameters(**values), x, np.zeros(16))
        expected_h = np.zeros(16)
        expected_h[3] = 0.5 * math.tanh(0.3)
        np.testing.assert_allclose(trace["h_new"], expected_h)
        expected_s = math.tanh(0.3) + 0.2
        self.assertAlmostEqual(trace["s"], expected_s)
        self.assertAlmostEqual(trace["p"], 1.0 / (1.0 + math.exp(-expected_s)))
        self.assertGreater(abs(trace["s"] - 0.2), 0.1)  # old-state head would give 0.2

    def test_every_equation_all_153_legal_dimensions_three_frames(self):
        for inputs in range(8, 17):
            for hidden in range(16, 33):
                with self.subTest(inputs=inputs, hidden=hidden):
                    params = GRUParameters.untrained(inputs, hidden, seed=100 * inputs + hidden)
                    model = FloatGRU(params, debug=True)
                    old = [0.0] * hidden
                    for frame in range(3):
                        x = np.sin(np.arange(inputs) * 0.7 + frame * 0.4)
                        expected = scalar_oracle(params, x, old)
                        model.step(x)
                        self.assert_trace(model.last_debug, expected)
                        old = expected["h_new"]
                    self.assertEqual(sum(v.size for v in params.as_dict().values()),
                                     3 * hidden * (inputs + hidden) + 4 * hidden + 1)

    def test_equations_with_nonzero_external_state(self):
        params = GRUParameters.untrained(9, 17, seed=23)
        old, x = np.linspace(-0.9, 0.8, 17), np.linspace(-1.2, 1.1, 9)
        self.assert_trace(evaluate_frame(params, x, old), scalar_oracle(params, x, old))

    def test_256_consecutive_frames_and_bounds(self):
        params = GRUParameters.untrained(16, 32, seed=31)
        model = FloatGRU(params, debug=True)
        rng = np.random.RandomState(91)
        old = [0.0] * 32
        for _ in range(256):
            x = rng.uniform(-2.0, 2.0, 16)
            expected = scalar_oracle(params, x, old)
            score = model.step(x)
            self.assert_trace(model.last_debug, expected)
            self.assertTrue(0.0 <= score <= 1.0)
            self.assertTrue(np.all(np.abs(model.hidden_state) <= 1.0))
            old = expected["h_new"]

    def test_state_persists_between_frames(self):
        params = GRUParameters.untrained(seed=2)
        model = FloatGRU(params, debug=True)
        x = np.linspace(-1.0, 1.0, 8)
        first_score = model.step(x)
        first_state = model.hidden_state
        second_score = model.step(x)
        np.testing.assert_array_equal(model.last_debug["h_old"], first_state)
        self.assertGreater(np.max(np.abs(model.hidden_state - first_state)), 1e-4)
        self.assertGreater(abs(first_score - second_score), 1e-5)
        self.assertEqual(FloatGRU(params).step(x), first_score)

    def test_new_call_clears_state_debug_and_replays_fresh(self):
        params = GRUParameters.untrained(seed=7)
        model = FloatGRU(params, debug=True)
        sequence = [np.full(8, v) for v in (0.1, -0.4, 0.9, 0.2)]
        first = [model.step(x) for x in sequence]
        model.start_call()
        np.testing.assert_array_equal(model.hidden_state, np.zeros(16))
        self.assertIsNone(model.last_debug)
        second = [model.step(x) for x in sequence]
        np.testing.assert_array_equal(first, second)
        fresh = FloatGRU(params)
        np.testing.assert_array_equal(second, [fresh.step(x) for x in sequence])

    def test_different_sequences_and_order_produce_different_outputs(self):
        params = GRUParameters.untrained(seed=4)
        a, b = np.linspace(-1.0, 1.0, 8), np.linspace(0.2, 0.9, 8)
        ab, ba = FloatGRU(params), FloatGRU(params)
        ab.step(a)
        ba.step(b)
        self.assertGreater(abs(ab.step(b) - ba.step(a)), 1e-4)

    def test_initialization_is_reproducible_and_does_not_change_global_rng(self):
        before = np.random.get_state()
        a = GRUParameters.untrained(seed=19).as_dict()
        after = np.random.get_state()
        for left, right in zip(before, after):
            np.testing.assert_equal(left, right)
        b = GRUParameters.untrained(seed=19).as_dict()
        c = GRUParameters.untrained(seed=20).as_dict()
        for name in a:
            np.testing.assert_array_equal(a[name], b[name])
            self.assertEqual(a[name].dtype, np.float64)
        self.assertFalse(np.array_equal(a["W_r"], c["W_r"]))

    def test_debug_mode_is_observational_and_snapshots_are_independent(self):
        params = GRUParameters.untrained(seed=5)
        debug, plain = FloatGRU(params, debug=True), FloatGRU(params)
        x = np.linspace(0.0, 0.8, 8)
        for _ in range(4):
            self.assertEqual(debug.step(x), plain.step(x))
        trace = debug.last_debug
        self.assertEqual(set(trace), {"x", "h_old", "a_r", "a_z", "r", "z", "q",
                                      "a_n", "n", "h_new", "s", "p"})
        trace["h_new"][:] = 99.0
        debug.hidden_state[:] = 99.0
        x[:] = 99.0
        self.assertFalse(np.any(debug.last_debug["x"] == 99.0))
        np.testing.assert_array_equal(debug.hidden_state, plain.hidden_state)

    def test_parameters_and_pure_inputs_are_copied_not_mutated(self):
        values = zero_tensors()
        params = GRUParameters(**values)
        values["b_n"][:] = 9.0
        params.as_dict()["b_n"][:] = 9.0
        x, h = np.zeros(8), np.full(16, 0.2)
        trace = evaluate_frame(params, x, h)
        np.testing.assert_array_equal(trace["n"], np.zeros(16))
        trace["x"][:] = 7.0
        trace["h_old"][:] = 7.0
        np.testing.assert_array_equal(x, np.zeros(8))
        np.testing.assert_array_equal(h, np.full(16, 0.2))

    def test_dimension_and_seed_validation(self):
        for name, invalid in [("inputs", [7, 17, 8.0, True, "8"]),
                              ("hidden", [15, 33, 16.0, False, None]),
                              ("seed", [-1, 2**32, 1.5, True])]:
            for value in invalid:
                with self.subTest(name=name, value=value):
                    with self.assertRaisesRegex(ValueError, name):
                        GRUParameters.untrained(**{name: value})

    def test_parameter_names_shapes_and_values(self):
        values = zero_tensors()
        missing = dict(values)
        del missing["b_z"]
        with self.assertRaisesRegex(ValueError, "missing=.*b_z"):
            GRUParameters(**missing)
        with self.assertRaisesRegex(ValueError, "extra=.*unknown"):
            GRUParameters(unknown=1, **values)
        for name in values:
            bad = dict(values)
            bad[name] = np.zeros((2, 3, 4))
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, name + " shape"):
                GRUParameters(**bad)
        for invalid in [float("nan"), float("inf"), complex(1, 1), "1.0", True]:
            bad = dict(values, b_s=invalid)
            with self.subTest(value=invalid), self.assertRaisesRegex(ValueError, "b_s"):
                GRUParameters(**bad)

    def test_frame_errors_preserve_state_and_debug(self):
        model = FloatGRU(debug=True)
        model.step(np.ones(8))
        old_state, old_trace = model.hidden_state, model.last_debug
        for invalid in [np.zeros(7), np.zeros((8, 1)), np.zeros((1, 8)),
                        np.full(8, np.nan), np.full(8, np.inf), np.ones(8, complex),
                        ["1"] * 8, [True] * 8, [[0], [1, 2]]]:
            with self.subTest(value=repr(invalid)), self.assertRaisesRegex(ValueError, "features"):
                model.step(invalid)
            np.testing.assert_array_equal(model.hidden_state, old_state)
            self.assert_trace(model.last_debug, old_trace)

    def test_hidden_shape_type_and_constructor_validation(self):
        params = GRUParameters.untrained()
        for invalid in [np.zeros(15), np.zeros((16, 1)), np.full(16, np.inf)]:
            with self.assertRaisesRegex(ValueError, "hidden_state"):
                evaluate_frame(params, np.zeros(8), invalid)
        with self.assertRaisesRegex(TypeError, "GRUParameters"):
            FloatGRU({})
        with self.assertRaisesRegex(TypeError, "GRUParameters"):
            evaluate_frame({}, np.zeros(8), np.zeros(16))
        with self.assertRaisesRegex(ValueError, "debug"):
            FloatGRU(debug="yes")

    def test_extreme_finite_logits_use_true_stable_sigmoid(self):
        for sign in (-1.0, 1.0):
            values = zero_tensors()
            for gate in ("r", "z", "n"):
                values["b_" + gate][:] = sign * 1000.0
            values["b_s"] = sign * 1000.0
            with np.errstate(all="raise"):
                trace = evaluate_frame(GRUParameters(**values), np.zeros(8), np.zeros(16))
            self.assertEqual(trace["p"], 0.0 if sign < 0 else 1.0)
            self.assertTrue(np.all(np.isfinite(trace["h_new"])))

    def test_finite_input_overflow_errors_without_partial_state_commit(self):
        values = zero_tensors()
        values["W_r"][:] = np.finfo(np.float64).max
        values["b_n"][:] = 0.2
        model = FloatGRU(GRUParameters(**values), debug=True)
        model.step(np.zeros(8))
        old, trace = model.hidden_state, model.last_debug
        with self.assertRaisesRegex(ValueError, "non-finite"):
            model.step(np.ones(8))
        np.testing.assert_array_equal(model.hidden_state, old)
        self.assert_trace(model.last_debug, trace)


if __name__ == "__main__":
    unittest.main()
