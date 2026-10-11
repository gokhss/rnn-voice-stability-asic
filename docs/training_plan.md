# Phase 3 training and evaluation plan

Status: plan only. No acquisition, training, label generation, package installation, quantization or source-code changes were performed. Follow [dataset audit](dataset_audit.md) and [target/features](prediction_target_and_features.md); the existing [float reference](../model/gru_float.py) remains the equation oracle.

## Approval and data readiness

1. Obtain explicit approval for an exact dataset/subset and bounded download, intended use and storage location. Resolve license/attribution/redistribution conditions. Prefer eligible NISQA subsets first; external TCD-VoIP and PSTN use remains conditional.
2. Inspect actual files before deciding training is possible. Record immutable source URL/version, hashes, file IDs, speaker/source/session/call IDs, duration/sample format, codec/domain, human MOS scale, count/variance of ratings, clean-pair linkage, and telemetry availability. Missing values remain missing. Document rejected samples and reasons.
3. Freeze target, A8 versus T12 profile, population/languages/codecs, correlation threshold and evaluation protocol with the owner. A8 can use audio plus clip MOS; T12 additionally needs valid synchronized telemetry and missingness diversity. Neither establishes time-local quality from clip labels alone.
4. Approve a separate floating training implementation scope and dependency decision. NumPy inference exists; gradient training does not. No permission to install an autodiff framework or execute training is inferred from this plan.

## Partition before deriving examples

Create a graph linking recordings by any shared speaker, original utterance, clean source, call/session, overlapping segment, or alternate microphone/channel. Put entire connected components into one partition. All corruptions, codecs, gains, excerpts and future augmentations of a source inherit its partition. Resolve identifiers across corpora; do not assume dataset names guarantee independence. Use file hashes plus decoded-audio duplicate checks for exact/re-encoded sources; similarity checks supplement provenance but do not prove speaker identity.

Prefer published evaluation partitions only after their leakage properties are checked. Audit NISQA SIM/LIVE source and speaker relations jointly; never split rows randomly across these related subsets. A proposed fallback is seeded approximately 70/15/15 train/validation/test allocation by components (seed 17), stratified where feasible by quality and domain. Group boundaries outrank target fractions. Actual group counts and feasible fractions cannot be determined before acquisition. If grouping produces too few independent components, report that failure rather than weaken the split.

Missing speaker IDs preclude a verified speaker-disjoint claim. Keep known-source/session groups together, report residual risk, and prefer a separately sourced test corpus with verified identity provenance. Repeated text without shared speakers should be reported; optionally hold out prompts as an additional stress split. Noise recordings, device/provider identities and impairment recipes get dedicated unseen-condition tests; their reuse must be disclosed, especially for simulation. Never construct a long test call by concatenating train recordings and claim independence.

Save split membership, grouping reasons, seed, content hashes and a leakage report before normalization, feature caching or augmentation. Every cached artifact includes split and frontend hashes. Fit all preprocessing and calibration on train/development only. Evaluation selection must not use test MOS or test prediction failures to retune the model. Keep external test data sealed until the design is frozen.

## Floating training implementation to propose next

Preserve the approved equations: r and z see immutable old h; candidate uses U_n*(r*h_old) with bias outside; z preserves old state; sigmoid head sees fully updated h. Train all three W/U matrices, three bias vectors, W_s and b_s. No frozen random head. Baseline I=8,H=16; optional I=12 telemetry and H=32 are validation-selected experiments, not automatic architecture changes.

Use a custom differentiable cell implementing these equations if a suitable framework is approved. Do not substitute a framework's default GRU without proving reset placement, bias placement and update polarity. Export floating arrays into the existing GRUParameters object in a new artifact location; compare every intermediate against FloatGRU with a declared dtype-dependent tolerance. The float64 oracle remains independent and unchanged. Check gradients with finite differences on small synthetic examples and verify an overfit-to-tiny-training-subset sanity test before a real experiment; neither establishes generalization.

Proposed initial experiment: full-clip backpropagation through time, masked variable-length batches of eight independent clips, Adam learning rate 0.001, global gradient norm limit 1, at most 100 epochs with patience 10 on validation MOS RMSE. Use seeds 0, 1, 2 and report all runs; select a checkpoint using validation only. These are starting hyperparameters to approve and record, not tuned findings. Use equal clip-weighted MSE on the pooled sigmoid outputs defined in the target contract; begin with no augmentation. A changed waveform must not silently inherit an unchanged human label.

Use zero state at real call/clip boundaries; preserve state and chronological ordering within each sequence. Mask padding out of recurrence and loss. Do not shuffle frames. Detached chunks, if later necessary for long recordings, must carry state and be documented as truncated BPTT; a clip-level loss needs an explicitly correct pooling/gradient method, not duplicated clip labels on chunks. Full-clip training first avoids that ambiguity. Independent clips are not evidence about one-hour hidden-state behavior.

Keep a constant training-mean MOS baseline and an order-insensitive/simple acoustic baseline, using the same data/splits. Perform validation-only ablations of recurrence, features, telemetry, hidden size and missingness. A larger network is not automatically justified. Do not introduce fixed-point constraints, LUTs or QAT in this floating scope.

## Evaluation and alert validation

Primary: pre-registered human-MOS Pearson correlation, with the proposed >0.80 threshold confirmed before training. Report Spearman, MAE/RMSE, prediction range and calibration without fitting a nonlinear mapping on test data. Evaluate each corpus/domain separately as well as a declared aggregate; a pooled correlation can hide domain bias. Use 2,000 bootstrap resamples at the independent speaker/source/call-component level for 95% intervals (planned method); report unstable/undefined statistics. Report rating uncertainty and sample counts, not just a single score.

Report quality strata, codec/bandwidth, language, speaker group, noisy/silent/clipped/concealed audio, startup versus steady state, and observed versus unavailable telemetry where supported. Do not invent demographic attributes or unsupported labels. Inspect cases where network impairment was concealed successfully; network-event accuracy is not perceived-quality accuracy.

For continuous labeled calls, evaluate per-window score pooling and runtime EMA separately. Choose alert assertion/recovery thresholds and K on validation only, with the approved strict threshold comparisons and first-score EMA initialization. Owner must specify degraded/recovered quality levels, false alarms per hour and detection/recovery delay targets before alert acceptance can be judged. Report event sensitivity, missed degraded duration, false alarms/hour, precision/recall, duration of false alert, onset/recovery delays, and denominator definitions. Human-window overlap and label latency limit event timing resolution; do not claim millisecond perceptual detection from one-second labels.

Proposed event matching: pair each predicted alert onset with at most one labeled degradation onset within a predeclared tolerance, then count unmatched alerts/events. Set that tolerance with the labeling protocol before evaluation, not after seeing results. Explicitly include new calls, silence, reset mid-call and quality transitions. Synthetic impairment traces support control/timing stress tests but cannot alone establish human false-positive/negative rates. The required one-hour system-equivalence test remains later verification; no such run occurred here.

## Reproducibility outputs for an approved training run

Produce data/license manifest, rejected-record log, split/group manifest, frontend/normalization manifest, exact environment lock, seeds/config, untrained initialization identity, epoch metrics, selected floating checkpoint, oracle comparison, per-example held-out predictions and aggregate metrics with confidence intervals. Record source revision and hardware/software used. Put new artifacts in versioned locations; preserve old test weights. Do not publish restricted audio or labels in the repository. Reproduction instructions must distinguish synthetic functional tests from real model evaluation.

## Data required by later QAT, without implementing it

QAT will require the accepted trained floating checkpoint and its reset-before identity; frozen feature/normalization definitions; representative labeled training sequences across quality and telemetry conditions; training-only calibration/range observations; validation data for numerical-policy selection; and untouched test data for final comparison. Preserve call boundaries, sequence order, silence/startup, rare impairments and long-stream examples. Calibration data is not a substitute for quality labels when fine-tuning a supervised model.

Later compare float and quantized predictions on identical sequences and against human targets: score MAE/max error, correlation/RMSE changes and alert-event changes. Separate frontend, weight/activation quantization and nonlinearity approximation effects. Candidate signed INT8 Q7 range may not fit learned weights; training statistics must inform a separately approved scale/QAT decision. No ranges, quantized arrays, fake-quant operations or LUTs were generated in Phase 3.

## Readiness

Planning is complete for review; execution is blocked on approved data/access, actual label/group audit, target/profile/metric decisions and training dependencies. The small feature GRU may be inadequate; only held-out experiments can resolve this. Do not proceed directly to Phase 4: this narrowed Phase 3 did not implement or train a pipeline. Recommend an explicitly approved acquisition/schema inspection followed by a separately authorized floating training task before considering QAT.
