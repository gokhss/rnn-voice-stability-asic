# Implemented GRU accelerator — verification checkpoint

This checkpoint implements the existing reset-before equations in the existing RTL modules. It is not a trained voice-quality model, QAT result, physical signoff or measured power result. The original `gru_float.py`, `gru_reference.py`, `quantize.py`, coefficient generator, old weights and old vector file remain byte-identical to the recovery snapshot.

## Implemented behavior and explicit contract resolution

The prototype integer reference was an 8-hidden Q12-weight implementation with PWL activations, mean-hidden score projection and finite-window average. The approved mathematical/numerical/interface specifications instead select configurable 8–16 inputs, 16–32 hidden units, signed INT8 F7 weights, a loadable scalar head, direct activation tables and EMA. Treating these implementations as bit-identical would be incorrect.

The target follows the approved specifications. `model/gru_hardware.py` is an **additional** hardware-format oracle; the original references were not edited to accommodate RTL. It preserves z/r dependencies on immutable old state, `U_n @ round(r*h_old)`, candidate bias outside the reset product, and `z*h_old+(1-z)*n` with a single blend rounding. The head consumes atomically committed new state. A separate comparison isolates coefficient conversion from the activation change. The untrained default hardware fixture converts old Q12 weight codes by nearest/ties-away division by 32, not byte truncation. Its head is loaded with equal weights reproducing the old mean for H=16/32; the hardware accepts arbitrary head weights/bias. Directed zero-head tests verify that score is not hardwired to mean(hidden).

| Quantity | Implemented representation |
|---|---|
| Matrix/head weights | signed 8-bit F7, real range −1…127/128, actual byte storage |
| Inputs/gates/candidate/hidden state | signed 16-bit F12 |
| Matrix products | mathematical signed 24-bit F19, sign extended through physical 16×16 multiplier |
| Biases | signed 32-bit F19; old Q12 bias code converted by shift left 7 |
| Accumulator | signed 40-bit; bias loaded already aligned |
| Matrix requantization | nearest/ties-away shift 7, then signed16 saturation |
| Reset product and blend | full signed32 products/F24; shared40 accumulator; shift12, ties away, signed16 saturation |
| Nonlinearities | frozen 513-entry sigmoid and 257-entry tanh magnitude tables; nearest 1/64 address, Q12 output, symmetry restored |
| Score/average | unsigned F16; score=min(65535,sigmoid_code<<4); typical ROM endpoints 16…65520 |
| EMA | first score initializes; then unsigned clamp of A+round_signed((P−A)/2^K), K=0…8 |

Worst unrestricted matrix accumulation is bounded by `2^31 + 48*32768*128 = 2,348,810,240`, well within signed40. Tests exercise both signs of maximal bias/product accumulation. Arithmetic clamping sets the per-frame SAT event; activation domain limiting is not arithmetic overflow.

The selected target contains no window divider. The existing finite-window module branch remains available as `EMA_MODE=0` solely to retain its original standalone regression; top selects `EMA_MODE=1`. The default top's synthesized hierarchy contains no `$div`/`$mod`. Historical finite-window behavior is not described as EMA equivalence.

## Datapath and interfaces

One variable signed16×16 multiplier and accumulator perform z/r/n dot products, r*h, both blend products and the head. Controller sequence: z → r → all reset products → n → all blends → atomic hidden commit → head → publication. Reset-gate scratch is overwritten with q only after all reset gates exist; candidate reads complete q. Old state is never overwritten neuron-by-neuron. Unreset scratch/weight arrays are inaccessible to valid operations until initialized by sequencing/loading. Synchronous reset/flush aborts work and clears persistent state/history.

The existing top name and packed `features`, `frame_valid`, `frame_ready`, `stability_score_out`, `running_average`, `score_valid`, `average_valid`, `busy`, `degradation_alert` names are retained. `score_valid` is the one-cycle frame-done indication and coincides with average publication. Direct `enable` is an additional admission gate: both it and CSR ENABLE must be high. Disabling either gate does not cancel accepted work. Direct `threshold`/`window_length` configuration pins were replaced by the already documented CSR threshold pair/EMA shift; users of the prototype top must migrate these connections. This is an interface migration, not drop-in pin compatibility.

The CSR map and sequential INT8/INT32 loader implement [interface_specification.md](interface_specification.md), addresses 0x00–0x38. All configured model words must be supplied before commit/enable. Invalid sign extension, incomplete commit, oversized image, illegal addresses/accesses/thresholds/K and writes during execution are rejected. Model memory is not reset; model_valid is. Flush preserves loaded model and aborts old-call work. Sticky IRQ events are maskable, W1C, and event-set wins over clear. Alert asserts on A<L and recovers on A>U; equalities retain state. No output ready is provided: holding result registers plus strobes are the documented output contract. Input ready provides backpressure; no queue or CDC adapter was added.

The unused top-level hidden-state mirror was removed, not disconnected from recurrence: storage and all consumers remain in `gru_cell`; verification reads the cell output hierarchically. Its unused external diagnostic port is intentionally open at the top, with a localized PINCONNECTEMPTY annotation. The compatibility-only window input has a localized unused annotation in the EMA specialization. Strict top-level lint is otherwise warning-free. The controller instance and width extensions were rewritten explicitly to support installed Yosys 0.9, without changing arithmetic.

## Actual verification

Full commands and tool output are preserved under [reports/hardware](../reports/hardware/), including timestamped complete regression logs, baseline logs and the interrupted-runner failure. Earlier synthesis/parser failures are summarized below; their overwritten full attempt logs are not claimed as retained. No failing assertion was removed to produce a pass. Existing benches were adapted to target dimensions/arithmetic; the original 128-frame Q12 cell/top and finite-window baseline passed before migration. Old vector files remain intact. The old finite-window test still runs; target cell/GRU checks now compare against generated hardware-format vectors.

| Executed check | Actual result |
|---|---|
| Original Python suite before changes | 21 passed |
| Original Verilator baseline | three benches passed; prototype score latency 442 cycles |
| Final `make test` | exit 0; 26 Python tests passed; all four RTL benches plus dimension/stress runs passed |
| Baseline target I=8/H=16 | 256 oracle frames; z, r, q, n, new hidden, score, EMA, alert and SAT exact; 1,380-cycle latency |
| Maximum target I=16/H=32 | 256 oracle frames; same exact comparisons; 5,060-cycle latency |
| Maximum saturation image | 128 oracle frames; signed INT8 endpoints and INT32 bias endpoints, exact results/SAT |
| Activation RTL versus Python tables | every signed16 input code (65,536), both functions, exact |
| MAC arithmetic | both tie signs at shifts7/12, sub-half cases, both saturation signs, 48-term extreme bounds and bias alignment passed |
| EMA standalone | 900 valid updates across all K=0…8, initialization, signed updates and idle hold passed |
| Integrated controls | model loading, incomplete/invalid/excess writes, CSR reads/errors, reset while busy, flush while busy and at completion, external disable drain, input latching/backpressure, consecutive legal offered beats, output holding, IRQ clear/set priority, threshold crossing/recovery/equality passed |
| Strict Verilator `--lint-only --Wall` | baseline and maximum top configurations: exit0, zero warnings |
| One-hour equivalent | **180,000 frames** at assumed 20 ms cadence; no flush between those frames; all gate/state/output comparisons passed |

The long run is an accelerated functional simulation, not one wall-clock hour or a real telecom call. It took 166.933 seconds reported simulator wall time, representing 3,600 seconds at 20 ms/frame. The vector's first frame flushes; the following 179,999 retain state. Preliminary reset/flush/loader tests and later directed head/control tests are additional to that count. The long run used the same final datapath and oracle; a subsequent bench-only extension added the explicit continuously offered two-frame transaction check, which passed in the final normal regression. No gate-level simulation, formal proof, all-153-configurations RTL sweep or PDK timing simulation is claimed.

Simulation builds still report testbench/RTL timescale notices and legacy finite-window width warnings. They are preserved in logs; the selected target's strict standalone RTL lint passes. No issue is hidden by counting Python-only tests as RTL coverage.

## Measured numerical differences (synthetic, untrained)

On 1,024 deterministic frames, I=8/H=16, seed17, call reset every97 frames:

| Comparison, normalized score units | Mean absolute difference | Maximum absolute difference |
|---|---:|---:|
| Original Q12 versus F7 conversion retaining old PWL | 0.0005340576 | 0.0024414063 |
| Original Q12/PWL versus complete hardware F7/ROM | 0.0017893314 | 0.0065917969 |
| Hardware versus floating oracle with same decoded F7 parameters | 0.0009850923 | 0.0022037653 |

Exhaustive ROM-to-mathematical errors: sigmoid maximum **0.0020448778**, tanh maximum **0.0078669532**. These meet the approved numerical bounds, not a MOS-accuracy criterion. All numbers and conditions are in [format_comparison.json](../reports/hardware/format_comparison.json) and generated `generation.json`. The old-to-new comparisons include recurrence; the full difference includes the intentional activation change. Floating comparison excludes coefficient-quantization loss because both sides use identical decoded F7 parameters. No trained-weight, MOS, QAT or alert-quality conclusion follows.

## Operations, cycles and resource evidence

Multiplications/frame = `3H(I+H)+4H`: 1,216 baseline, 4,736 maximum. The 4H term is H reset products, 2H blend products and H head products. Controller overhead produces `C=3H(I+H)+14H+4`, matching measured **1,380 / 5,060 cycles**. At the proposed **10 MHz**, those are **138 / 506 microseconds**; throughput is comfortably below 10 ms frame spacing if timing closes. The latency-in-cycles result is simulated; 10 MHz timing closure is not measured. `constraints/top.sdc` and configuration now consistently request a 100 ns period.

Installed Yosys 0.9 completed generic synthesis/ABC mapping and `check -assert` for baseline 8/16. [resources.json](../reports/hardware/resources.json) reports:

* One variable 16×16 `$mul`; the other pre-map multiply has a constant operand for address arithmetic and maps to logic.
* INT8 memory: 1,168×8 bits; bias memory: 49×32 bits; scratch z/q/n: three16×16 arrays. Model storage totals 1,364 bytes. No 16-bit weight array.
* **51,931 generic Boolean/FF primitive cells**, including **12,555 flip-flop bits** and 26,441 mux primitives after memory mapping. These are not standard-cell area or FPGA LUT counts.
* No residual memory black boxes, divider, multiplier primitive or latch after mapping. Activation tables became combinational logic; they were not mapped to foundry ROM macros.
* Flattened longest topological path: **93 Boolean-cell levels**, ending at score-register input through MAC rounding/activation/formatting. This is a structural depth, not delay, Fmax, timing slack or a physically measured critical path.

Resource reuse is evidenced by one variable multiplier; q/r scratch reuse removes H×16 storage bits relative to separate r/q arrays. No before/after technology-area or power percentage is asserted. Register-mapped coefficient memories dominate storage/mux cost and are a concrete future memory-mapping optimization opportunity. The implementation uses clock enables and operand isolation, not combinational gated clocks. Low-milliwatt power remains unmeasured.

Genus, Innovus, Tempus and Xcelium are not installed on PATH; no local technology configuration is present. Therefore no Liberty area, technology STA, post-route timing, switching-activity power, DRC/LVS or physical signoff result exists. Generic synthesis is not Cadence success.

## Reproduction and retained failure evidence

Run from the repository root:

```sh
make test
bash scripts/run_generic_synthesis.sh
python3 -B scripts/summarize_hardware.py
yosys -Q -T -p 'read_json build/hardware_generic.json; hierarchy -top voice_stability_top; flatten; ltp -noff' > reports/hardware/logic_depth.log 2>&1
python3 -B model/gru_hardware.py --out build/hardware_hour --frames 180000 --flush-every 0
build/obj_tb_voice_stability_top/Vtb_voice_stability_top +DATA=build/hardware_hour +FRAMES=180000
```

The runner prints each actual command, preserves compiler/simulator output and ends with `REGRESSION_EXIT=0` only on success. No external package installation is needed. Verilator/standard C++ toolchain, Python+NumPy and Yosys are used; Cadence is optional and not invoked here. `make model` remains the historical fixture generator; the target regression does not consume or regenerate those old weights/vectors.

Earlier failures were tooling/integration issues, preserved honestly: baseline ccache could not write `/run/user/1000`; rerun with temporary/cache paths under `/tmp` passed. Yosys 0.9 rejected wildcard port connections and sized SV casts; explicit connections/extensions fixed parsing. An early synthesis pass sequence collected memories before absorbing write clocks; inserting `memory_dff` before collection allowed complete mapping. One intermediate regression runner exited127 because the shell file was edited while executing; the complete unchanged runner was rerun successfully. No RTL numerical mismatch occurred in the reported oracle runs. Full output and the final resource JSON support the completion claims above.

## Changed files and recovery

Modified existing modules: `gru_cell`, `gru_controller`, `mac_unit`, `weight_rom`, `sigmoid_lut`, `tanh_lut`, `hidden_state_reg`, `stability_score`, `moving_average`, `alert_controller`, `voice_stability_top`. `feature_buffer` is unchanged. Modified three existing benches, simulation runner, Makefile, clock configuration/SDC and README status link.

Added `model/gru_hardware.py`, `model/compare_hardware_formats.py`, `tests/test_gru_hardware.py`, `tb/tb_ema_alert.sv`, `scripts/run_hardware_regression.sh`, `scripts/run_generic_synthesis.sh`, `scripts/summarize_hardware.py`, this report, generated target vectors/images, resource JSON/netlist artifacts and logs. New images are explicitly untrained functional fixtures, separate from preserved old hardware weights.

No Git metadata is present: `git status`/`git diff` cannot describe this tree. Recovery archive/hash manifest and a reconstructed source diff are in workspace `recovery/rtl-implementation/`; [change_manifest.json](../reports/hardware/change_manifest.json) records actual modified/new source files and protected-file hashes. No unrelated original file was deleted. Earlier dataset/training reports and acquired data are unchanged.

Next concrete implementation step: map coefficient/scratch memories against an available target library and run technology-qualified timing/activity-based power analysis at 10 MHz. Resolve timing/area from those measurements before adding pipelines or changing scheduling. Keep this regression as the equivalence gate. Real-world model accuracy and QAT remain separate, unperformed work.
