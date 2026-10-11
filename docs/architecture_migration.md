# Architecture migration checklist

This checklist is intentionally separate from the target architecture so that a planned design is not confused with implemented/verified RTL.

- [ ] Change RTL and testbench defaults together to 8 inputs / 16 hidden units.
- [ ] Replace 16-bit weights with signed INT8 weight storage and ports; document bias format.
- [ ] Train/calibrate model and export actual quantized weights; keep synthetic weights only as bring-up fixtures.
- [ ] Add `flush_state` through top/controller/hidden-state bank and specify whether per-call average/alert state clears.
- [ ] Replace variable-divider circular mean with shift-based EMA and implement identical signed rounding in Python and RTL.
- [ ] Replace combinational threshold compare with stateful hysteresis (assert and recovery thresholds).
- [ ] Add AXI-Stream adapter and documented control/status register map.
- [ ] Add weight loading or document a trained, preloaded weight image and how it is selected.
- [ ] Regenerate reference vectors for the chosen dimensions and quantization.
- [ ] Add tests for backpressure, flush, hysteresis, reset-mid-call and 180k/360k-frame stream.
- [ ] Run simulator and lint; record exact tool/version and logs.
- [ ] Run Genus/Innovus only with valid technology libraries and constraints; report measured results honestly.
