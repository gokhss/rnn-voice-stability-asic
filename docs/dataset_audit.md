# Phase 3 dataset audit

Status: documentation-only audit and planning. No dataset acquisition or training authorized. Reviewed 2026-10-11 Asia/Kolkata (2026-10-10 UTC). Statements below distinguish local evidence, publisher descriptions, proposed use, and unresolved access. Start with [Phase 3 report](phase3_report.md) for scope and checks.

## Local evidence

All 68 existing project files were inventoried and checkpointed. Read the Phase 0/2 reports, approved mathematical specification, target architecture, floating reference, older model/generator and available artifacts. Searches for data/training/feature/quality terms found no dataset ingestion, audio feature extractor, training loop, real quality labels, or recorded network telemetry. No audio, packet capture, NumPy dataset or trained-model checkpoint files were found in the project inventory. This finding covers this project, not external disks or unpublished owner data.

| Existing evidence | Actual meaning | Reuse / limitation |
|---|---|---|
| `model/gru_float.py`, `tests/test_gru_float.py` | Float64 reset-before GRU and scalar-oracle functional tests | Future inference/export oracle; default parameters explicitly untrained; no optimizer, audio frontend or labels |
| `model/generate_weights.py`, `build/weights.tsv` | Deterministic arithmetic-generated old Q12 coefficients | Functional fixtures, not learned weights or examples with MOS |
| `model/gru_reference.py`, `tb/test_vectors.mem` | Old integer reference and synthetic regression stimulus | Arithmetic verification only; not voice data |
| `reports/model.json` | Two activation approximation error fields | No predictive-quality metric or training history |
| `reports/qor.json` | Implementation reporting artifact | Not evidence of speech prediction accuracy |
| `docs/requirements_traceability.csv` | Requirements mapping | Not a label table |
| Three research PDFs | Research background | Not dataset samples or permission to reuse external corpora |

No existing feature names/order/units have been validated against actual recordings. Proposed definitions in [target and features](prediction_target_and_features.md) are engineering specifications to review, not discovered metadata. Phase 2 functional success is historical evidence of equations, not learned accuracy.

## Candidate corpus evidence

Verification level: primary publisher/author web pages and selected paper text only. No archive contents, audio, CSV rows, hashes, speaker identities or license files inside archives were inspected. Reported availability is not a successful download. Dataset versions, file-level permissions and integrity must be checked after an approved acquisition. Code/model licenses do not automatically license data.

### NISQA corpus — first candidate for MOS development

**Publisher facts:** simulated and live-call degraded speech; overall MOS plus noisiness, coloration, discontinuity and loudness ratings. SIM metadata is described as containing original distortion parameters and source identifiers; clips are 6–12 seconds. Access is through the TU Berlin deposit and Zenodo mirror linked by the authors. Corpus permissions inherit source speech/noise terms: the authors describe general noncommercial research availability, with only some subsets permitting commercial use. Individual archive licenses remain unchecked. [Author corpus page](https://github.com/gabrielmittag/NISQA/wiki/NISQA-Corpus).

**Proposed use:** first inspect rights and speaker/source IDs, then use eligible SIM/LIVE training data and genuinely disjoint held-out data. Audio supports energy/spectrum/noise-proxy extraction. Simulation settings may describe packet loss/SNR but are not verified per-frame receiver measurements. RTP jitter traces, clean pairs, PESQ targets and time-local MOS are not established by this inspection. Do not populate runtime telemetry with file-wide distortion settings. Clip-level MOS and mixed recording conditions leave a temporal-label/domain gap. This is a candidate, not an acquired or cleared dataset.

The NISQA implementation distinguishes MIT code from CC BY-NC-SA model weights; neither substitutes for corpus terms. We will not import its pretrained model as PS-01 ground truth. [Author repository](https://github.com/gabrielmittag/NISQA).

### TCD-VoIP — independent degradation stress set

**Publisher facts:** speech with subjective opinion scores from 24 listeners; chopping, clipping, competing speech, echo, noise and MNRU conditions. The official page links a Google Drive download and states noncommercial-only use. It lists chop and SNR condition parameters. Full redistribution/derivative terms and archive metadata were not inspected. [Publisher page](https://sigmedia.tv/datasets/tcd_voip_ltd/).

**Proposed use:** external evaluation after rights and source/speaker grouping checks. Compute acoustic features from degraded speech. Known imposed SNR/chop settings are analysis strata, not receiver SNR or measured packet loss. RTP jitter, packet timing, time-local MOS and supplied PESQ labels are unverified; clean-reference pairing must be inspected before proposing objective reference scores. Controlled distortions help isolate failure modes but do not establish continuous live-call accuracy. Do not tune hyperparameters on this set if it is designated external test data.

### PSTN quality corpus — conditional real-call evaluation candidate

**Author evidence:** the PSTN paper describes an open-source test set of more than 1,000 crowdsourced real calls, subjective MOS evaluation, and a setting where network indicators are unavailable. [Paper abstract](https://arxiv.org/abs/2007.14598), [paper text](https://arxiv.org/pdf/2007.14598).

**Access / license:** release identity, currently usable author download and data license have not been verified. Access must be resolved through the paper's authors/release documentation; do not use third-party mirrors as proof of permission. No permission request was sent. This candidate is blocked for acquisition/use until those points are resolved. The paper's arXiv license is not a corpus license.

**Proposed use:** held-out real-call MOS evaluation if obtainable with appropriate rights. Received audio can supply acoustic features; per-packet jitter/loss and true SNR are not assumed available. MOS is supported by the paper, but actual label schema, clean pairs, supplied PESQ scores, speaker IDs and temporal labels remain unchecked. Do not conflate similarly named later PSTN releases or copy their counts into this dataset record. Country/provider and rating-distribution shifts may limit correlation; no published model result is a result for our GRU.

### VCTK 0.92 — clean source for a future controlled experiment

**Publisher facts:** 110 English speakers, roughly 400 sentences each, 48 kHz released audio and speaker-organized speech/transcripts. Edinburgh DataShare provides the archive; its full metadata declares CC BY 4.0. The linked license text could not be retrieved in this browsing session, so archive notice/attribution details still need inspection. [Dataset record](https://datashare.ed.ac.uk/handle/10283/3443), [rights metadata](https://datashare.ed.ac.uk/items/30e7453c-9ea8-48b4-8e18-f96d0dc62928/full).

**Proposed use:** speaker-disjoint clean sources for an explicitly simulated codec/network experiment, not primary quality supervision. There are no verified quality MOS/PESQ labels or RTP traces here. Audio features are computable; controlled noise SNR, packet-loss decisions and jitter become known only if a future approved simulator creates and logs them. Obtaining clean/degraded pairs could enable a separately licensed full-reference metric. Synthetic corruption settings are not MOS labels. Read speech in a recording studio does not validate conversational telecom quality, and reused VCTK-derived corpora must be grouped to prevent leakage.

## Selection and access gate

Recommend NISQA subset/license inspection first, TCD-VoIP as an independent stress test if permitted, and an instrumented real-call validation collection as the eventual application test. VCTK simulation is supplemental; PSTN is conditional on resolving its release and terms. No candidate inspected here establishes all of MOS, per-frame labels, real telemetry, and long continuous calls.

Before downloading: owner chooses research-only versus intended commercial scope; approves exact subsets, download size/location and any costs; inspect publisher rights and redistribution restrictions; record version/URL/date/attribution. After acquisition: archive hashes, actual schema, audio counts/durations, MOS range/rating counts, speaker/source/session linkage, codec/sample rates, telemetry and reference-pair availability must be verified. Reject unusable licenses or unknown label semantics rather than assigning convenient defaults. No commercial-use clearance is claimed.

## Evidence limits and blockers

No meaningful predictive-accuracy claim is currently supportable: no local real data, learned model, held-out predictions or human-quality evaluation exists. Most candidate supervision is clip-level; accurate alert onset/recovery needs time-local quality labels on continuous calls. Acoustic impairment can sometimes be detected without telemetry, but jitter and packet loss cannot be uniquely reconstructed from decoded audio. A network event is not necessarily perceptual degradation after jitter buffering and concealment. Rights, deployment frontend, target population/languages/codecs, speaker provenance and alert operating criteria remain open.
