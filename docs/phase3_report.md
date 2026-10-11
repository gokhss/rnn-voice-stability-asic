# Phase 3 — dataset audit and training planning report

Status: authorized **planning-only Phase 3 complete for owner review**. No training pipeline was implemented or run. Phase 4 and later work remain unauthorized. This report describes current scope; earlier phase reports remain unchanged historical records.

## Deliverables and findings

| New file | Contents |
|---|---|
| [dataset_audit.md](dataset_audit.md) | Local artifact audit; primary-source dataset/access/rights evidence; per-dataset labels, features and application gaps |
| [prediction_target_and_features.md](prediction_target_and_features.md) | Continuous MOS target, clip-versus-frame distinction, proposed A8/T12 feature definitions and normalization |
| [training_plan.md](training_plan.md) | Acquisition gates, leakage prevention, floating training/evaluation plan, future QAT data needs |
| [phase3_report.md](phase3_report.md) | Scope, actual checks, preservation and remaining decisions |

Existing project files modified: **none**. Files deleted: **none**. README, architecture contracts and requirements CSV remain unchanged; new proposals do not silently amend their approved mathematical specification. All 68 starting files were SHA-256 checked against the recovery manifest and remain identical.

No suitable local voice dataset, human quality labels, network traces, feature extractor, trained checkpoint or training pipeline was found. Existing coefficient/vector files are synthetic untrained functional fixtures; `reports/model.json` reports activation errors, not prediction accuracy. The NumPy reference is reusable as a mathematical oracle, not as a trained predictor.

## Research verification and selection

Four candidate corpora were investigated through primary author/publisher descriptions: NISQA, TCD-VoIP, PSTN and VCTK 0.92. Source links and evidence limits are recorded in the dataset audit. No corpus audio, label CSV, archive contents or per-file licenses were downloaded or inspected.

NISQA is the recommended first rights/schema inspection for clip-level human quality labels; TCD-VoIP is a possible independent degradation test. PSTN is conditional on identifying an accessible release and its data license. VCTK is a clean speech source for possible later controlled experiments, not labeled voice-quality training data. NISQA has source-dependent rights, TCD's publisher states noncommercial-only, VCTK's rights metadata states CC BY 4.0, and PSTN corpus rights remain unresolved. These descriptions are not blanket commercial-use clearance.

Publisher pages support human clip-quality supervision for the first three candidates; none of the inspected evidence establishes synchronized 10 ms MOS plus receiver telemetry. Received audio permits acoustic feature computation. File-wide simulated loss/SNR settings must not be treated as per-frame measurements, and jitter cannot be inferred uniquely from audio. PESQ-derived labels were not verified as supplied for any selected release. No dataset has been accepted for use yet.

## Proposed target and features

Recommend regression of human overall MOS normalized by `(MOS−1)/4`, retaining the learned scalar sigmoid head. For the initial clip-labeled experiment, supervise the mean of causal frame scores against clip MOS. This preserves a testable correlation objective, but leaves individual frame trajectories weakly supervised. It cannot validate event timing or instantaneous quality. Classification is secondary and must not replace the required score-correlation assessment.

Propose eight audio features: energy, a causal SNR proxy, four spectral-band fractions, zero-crossing fraction and spectral change. Baseline stays I=8/H=16 with the approved reset-before recurrence. A separately versioned optional I=12 profile adds receiver jitter, playout loss and their validity flags. No metadata-derived runtime feature has been invented; these are proposed definitions to implement only after approval. No feature extractor or model dimension was changed.

Recommend declaring Pearson r > 0.80 on untouched human-MOS evaluation data before experimentation, with grouped confidence intervals and additional error/rank metrics. This is an owner-review proposal, not a measured result. Continuous-call validation needs separate time-local labels, alert thresholds and detection-delay/false-alarm criteria. A clip-correlation result alone would leave that part of the application unverified.

## Actual checks and their limits

* Read the requested Phase 0 audit, Phase 2 report, mathematical specification, final architecture and floating Python reference; inspected existing generator/reference/artifact contents and searched project files for dataset, training, features and quality-label evidence.
* Inventoried all 68 starting project files, including hidden configuration and existing generated artifacts. No local audio/packet-capture/data-array/trained-checkpoint files were found; structured files were classified rather than assumed to be labels.
* Checked Git availability: this supplied project tree has no usable Git metadata. No clean-tree or commit claim is made. A full tar recovery archive and SHA-256 manifest were created and archive contents checked before additions.
* Read primary dataset pages, NISQA author documentation, PSTN paper text, Edinburgh rights metadata, RFC 3550 jitter definition and the ITU PESQ record through web tools. VCTK's linked license-text retrieval and the PSTN experimental HTML view returned tool errors; VCTK rights metadata and PSTN PDF text were readable. No acquisition success or license-file inspection is inferred from those fallback pages.
* Checked the interpreter/dependency availability: Python 3.10.12; NumPy discoverable; PyTorch, TensorFlow and pytest not discoverable. No dependency installed. Training framework selection remains open.
* Checked local Markdown links in these four documents, feature lane counts/order, and the proposal against the approved dimension/equation contract. Verified all 68 original file hashes and absence of deletions. Final check results are also recorded in the recovery run manifest.

No Python unit suite, model inference experiment, audio feature extraction, dataset statistics, leakage test on actual samples, training, predictive evaluation, quantization, RTL simulation or implementation flow ran in this phase. Phase 2's 21 passing functional tests are historical and were not rerun or reinterpreted as quality evidence. There are no MOS/correlation/false-alarm results to report.

## Recovery and file accounting

Workspace-relative checkpoint: `recovery/phase3-20261010T212141Z/`, outside the nested project. It contains `repository.tar.gz` and `manifest.json`, plus this run's `CHECKPOINT.md` and `run_manifest.json`. Restore the archive into a separate directory for comparison/recovery; do not overwrite current user files blindly. Temporary audit helpers outside the project are not training code or deliverables.

RTL, all existing SV/Python tests and fixtures, model weights, quantization code, synthesis/physical scripts, constraints and all other original files are unchanged. Only the four listed Markdown files were added to the project. Training, quantization, RTL work, synthesis and physical implementation were not started.

## Decisions and blockers for owner review

| Decision / blocker | Recommendation or evidence needed |
|---|---|
| Research-only or commercial intended use | Choose intended scope before selecting corpus subsets; inspect actual terms |
| Exact acquisition and budget | Approve specific corpus/version/subset, storage and bounded size; none acquired |
| Prediction meaning and metric gate | Approve normalized human-MOS regression and pre-registered correlation threshold; classification is secondary |
| Feature/deployment contract | Start A8 with received audio; approve T12 only with synchronized receiver telemetry; validate frontend feasibility |
| Data leakage | Inspect speaker/source/call relations and actual splits; no verified split exists locally |
| Temporal labels and alert criteria | Obtain continuous-call/window ratings and define acceptable false alarms and delays |
| Languages, bandwidth, providers/codecs | Define deployment population and unseen-domain tests |
| Training environment/model adequacy | Approve gradient framework and floating training scope; small-GRU accuracy remains unknown |

A meaningful predictive-accuracy claim is blocked by missing acquired data, validated labels/splits, training and held-out evaluation. QAT is premature without a validated floating baseline. Recommend the next authorization cover **bounded dataset acquisition/schema and license inspection**, followed by a separately authorized floating training implementation/run if the data passes review. This narrowed Phase 3 did not authorize that execution; do not automatically advance to Phase 4.

Stop here. Owner review and explicit approval are required before further acquisition, training or any later phase.
