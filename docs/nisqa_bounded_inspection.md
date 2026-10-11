# NISQA bounded acquisition and schema inspection

Status: authorized inspection complete; **no training or later phase started**. Inspection date: 2026-10-11 Asia/Kolkata, 2026-10-10 UTC. The approved Phase 3 planning documents were read and preserved. This report updates their evidence without rewriting historical findings.

## Decision

**NISQA is suitable for developing and evaluating clip-level continuous MOS regression, subject to subset rights and split validation. It does not by itself validate 10 ms quality scores or alert timing.** Actual CSV labels support the proposed `(MOS−1)/4` target. No model was trained, run on these clips or evaluated for predictive accuracy.

The downloaded sample establishes readable audio and label linkage, not statistical representativeness or model adequacy. Recommend retaining the approved A8 audio-feature baseline for a future authorized experiment. T12 telecom features remain unsupported by the inspected data. No alternative corpus was downloaded.

## Official provenance, access and bound

Followed the [author corpus wiki](https://github.com/gabrielmittag/NISQA/wiki/NISQA-Corpus) to its official [Zenodo mirror record 4728081](https://zenodo.org/records/4728081), published as v1 by Gabriel Mittag/TU Berlin. The record links DOI `10.14279/depositonce-11807.5`. Its ZIP is **15,945,499,507 bytes** according to the live HTTP header. The alternate TU Berlin link could not be parsed as a ZIP by the web tool; an initial web request to the mirror returned HTTP 429. Direct sandbox networking failed DNS; approved external network access subsequently worked without credentials or payment.

Used HTTP byte ranges to read the ZIP directory and selected members. Each response had to return HTTP 206 and the exact requested Content-Range, otherwise the reader would abort before reading the body. Cumulative response-body limit: **25 MiB**; actual: **12,544,598 bytes (11.963 MiB)**, including repeated small directory probes. No full archive was downloaded. Headers/TLS overhead and browser-rendered pages are not included in this byte count.

The initial 4 MiB per-read guard rejected the 4,553,532-byte central directory before transfer. The guard was raised to 8 MiB, keeping the 25 MiB cumulative cap; verified ranges were cached to avoid re-fetching the directory. ZIP64 directory inspection found 27,830 entries, including 27,773 WAV entries. Those counts include reference audio; they are not labeled-example counts. Member CRCs were checked by Python zipfile and extracted files hashed with SHA-256. The complete archive's published MD5 was **not** verified because the archive was not acquired.

All inspection assets are outside the project in [inspection/nisqa_bounded](../../inspection/nisqa_bounded/). [Acquisition manifest](../../inspection/nisqa_bounded/acquisition_manifest.json) records exact paths, sizes and hashes; [requests.json](../../inspection/nisqa_bounded/requests.json) records byte ranges/body hashes. [ZIP inventory](../../inspection/nisqa_bounded/zip_inventory.json) records directory entries. Range fragments are incomplete cached byte slices, not a reconstructable full ZIP. Do not treat these assets as an approved training dataset or redistribute the mixed-source metadata/audio under the repository code license.

## Actual license evidence

Read the extracted corpus, TRAIN_LIVE, TRAIN_SIM and TEST_LIVETALK READMEs, and the included LIVETALK CC BY 4.0 license. The selected audio is exclusively TRAIN_LIVE; its README says source Librivox/DNS speech is public domain and permits commercial and noncommercial **research** under source terms. Preserve attribution to Mittag, Naderi, Chehadi and Möller, “NISQA — A Deep CNN-Self-Attention Model for Multidimensional Speech Quality Prediction with Crowdsourced Datasets” (2021), with source links. This is sufficient for this bounded research inspection; no blanket product-deployment rights conclusion is made.

LIVETALK's included notice specifies research use under CC BY 4.0; the license requires retaining supplied attribution/license information and indicating modifications when sharing. Its audio was not acquired. SIM inherits separate speech/noise rights (including AusTalk, TSP, UKIRE and DNS/noise sources); the README was read but all underlying license PDFs/notices and per-file noise provenance were not audited. SIM metadata inspection does not clear all SIM audio for training or redistribution. NISQA code/model licenses are distinct from corpus rights.

**Material discrepancy:** the archive's root README explicitly says TEST_NSC was removed for license reasons. It is absent from the acquired directory and corpus CSV, although the public wiki still describes four test subsets. Do not attempt to restore it from a third-party mirror. No publisher was contacted.

## Exact data inspected

Extracted **14 members: seven text/CSV/license files and seven WAV files**:

* `NISQA_Corpus/NISQA_TEST_LIVETALK/CC_BY_license.txt` (19,047 bytes)
* `NISQA_Corpus/NISQA_TEST_LIVETALK/readme.txt` (1,863 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/deg/book_00007_chp_0008_reader_01326_58_seg_live_phone_601.wav` (1,152,046 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/deg/book_00084_chp_0006_reader_04891_43_seg_live_skype_608.wav` (1,056,046 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/deg/book_04723_chp_0001_reader_11431_23_seg_live_skype_271.wav` (1,056,046 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/deg/book_04733_chp_0031_reader_10929_10_seg_live_skype_272.wav` (960,046 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/deg/book_09868_chp_0005_reader_10362_41_seg_live_phone_537.wav` (1,056,046 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/deg/book_10134_chp_0013_reader_08463_21_seg_live_phone_550.wav` (960,046 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/readme.txt` (3,021 bytes)
* `NISQA_Corpus/NISQA_TRAIN_LIVE/ref/book_00084_chp_0006_reader_04891_43_seg.wav` (1,056,044 bytes)
* `NISQA_Corpus/NISQA_TRAIN_SIM/NISQA_TRAIN_SIM_file.csv` (4,776,883 bytes)
* `NISQA_Corpus/NISQA_TRAIN_SIM/readme.txt` (4,354 bytes)
* `NISQA_Corpus/NISQA_corpus_file.csv` (5,724,911 bytes)
* `NISQA_Corpus/readme.txt` (2,078 bytes)

The six degraded TRAIN_LIVE clips were selected deterministically by minimum, middle-ranked and maximum MOS within each call type, using path ordering to break ties. This deliberately broadens inspected conditions but is **not random sampling**. It contains no test audio and cannot estimate dataset/model performance.

| Degraded filename | Supplied MOS | Votes |
|---|---|---|
| `book_00084_chp_0006_reader_04891_43_seg_live_skype_608.wav` | 1.0 | 5 |
| `book_04723_chp_0001_reader_11431_23_seg_live_skype_271.wav` | 2.4 | 5 |
| `book_04733_chp_0031_reader_10929_10_seg_live_skype_272.wav` | 4.2 | 5 |
| `book_00007_chp_0008_reader_01326_58_seg_live_phone_601.wav` | 1.0 | 5 |
| `book_10134_chp_0013_reader_08463_21_seg_live_phone_550.wav` | 2.0 | 5 |
| `book_09868_chp_0005_reader_10362_41_seg_live_phone_537.wav` | 4.25 | 4 |

The additional reference is `book_00084_chp_0006_reader_04891_43_seg.wav`, linked by the CSV to the first selected Skype example. Reference audio does not inherit a fabricated quality label. All seven WAV files fully decoded through the standard-library wave reader as **mono, 48,000 Hz, 16-bit PCM**, with complete frame payloads. Degraded durations are approximately 10, 11 or 12 seconds (one extra sample); the selected reference is exactly 11 seconds. This is a sample-format finding, not a claim that every corpus file has this format. No listening study, resampling or alignment validation was performed.

## Schema and label checks

[Machine-readable results](../../inspection/nisqa_bounded/schema_results.json) contain all columns, subset statistics, path checks, overlap counts and WAV headers/hashes. The corpus CSV contains **14,432 rows**, 21 columns, no duplicate `(db,file)` keys, no duplicate degraded paths, no missing MOS and no nonfinite or out-of-[1,5] MOS. Every degraded path and every nonempty reference path resolves to a directory entry; existence does not prove that unacquired audio decodes or aligns.

| Subset | Rows | Observed MOS range |
|---|---|---|
| NISQA_TEST_FOR | 240 | 1.000–4.531 |
| NISQA_TEST_LIVETALK | 232 | 1.000–4.750 |
| NISQA_TEST_P501 | 240 | 1.000–4.889 |
| NISQA_TRAIN_LIVE | 1020 | 1.000–4.250 |
| NISQA_TRAIN_SIM | 10000 | 1.000–5.000 |
| NISQA_VAL_LIVE | 200 | 1.000–3.800 |
| NISQA_VAL_SIM | 2500 | 1.000–5.000 |

Columns: `db`, `con`, `file`, `con_description`, `filename_deg`, `filename_ref`, `source`, `lang`, `votes`, `mos`, `noi`, `col`, `dis`, `loud`, `noi_std`, `col_std`, `dis_std`, `loud_std`, `mos_std`, `filepath_deg`, `filepath_ref`.

The READMEs identify file-level averaged listening ratings. MOS and dimension averages, vote counts and dispersion fields are available, but no timestamped quality trajectory or event label is present. The metadata field names alone do not establish a confidence interval or standard-error convention for the `_std` fields. No individual-listener table was acquired. Numeric `file`/`con` IDs are local to a dataset, not global speaker or call IDs.

TRAIN_SIM's separate CSV has 10,000 rows and 51 columns: the common 21 plus filter/noise/clipping/level flags, `codec1..3`, `plcMode1..3`, `wbgn_snr`, `bgn_snr`, `tc_fer`, `tc_nburst`, `cl_th`, `bp_low`, `bp_high`, `p50_q`, `bMode1..3`, `FER1..3`, `asl_in_level` and `asl_out_level`. Blanks and `-` occur for inactive settings. These are file-level distortion-generation settings; units and inactive-value semantics need the generating documentation before modeling them. No RTP arrival timestamps, packet sequence/deadline trace, jitter-buffer log or per-frame loss labels were found in these inspected schemas. No PESQ/POLQA score columns were found. Clean references exist for many subsets, but LIVETALK has no supplied reference path; the inspected clean/degraded pair is not proof that a reference metric is valid without alignment and implementation checks.

## Feature feasibility against the approved contract

| Proposed inputs | What the actual sample supports | Remaining work |
|---|---|---|
| A8 lane 0 log energy | PCM samples and known full-scale encoding | Causal 48→16 kHz frontend, retain level; no per-clip peak normalization |
| A8 lane 1 SNR proxy | Causal energy-history proxy can be computed | It is not true SNR; simulated SNR settings must not become privileged runtime inputs |
| A8 lanes 2–5 band fractions | PCM permits spectral analysis | Approved bands end at 8 kHz; downsampling loses higher-band information potentially relevant to original MOS |
| A8 lane 6 zero crossings | Directly computable after chosen frontend | Resampling changes crossings; freeze frontend before extraction |
| A8 lane 7 spectral change | Consecutive PCM windows available | Reset at clip/call start; no observed packet-loss interpretation |
| T12 lanes 8–9 jitter/playout loss | Not supplied as required receiver measurements | Instrumented telecom logs or separately approved simulation required |
| T12 lanes 10–11 validity flags | Missingness can be marked explicitly | All-missing telemetry does not train or validate its predictive contribution |

No frontend implementation, normalization fit, feature-vector export or derived labels were created. The assessment is based on decoded signal availability and metadata, not feature accuracy tests. A causal anti-alias resampler must be selected and tested before A8 extraction; simply dropping every third sample is unsuitable. The 20 ms window/10 ms hop produces many correlated frames per clip but does not produce new independent labels. Fullband-versus-telephony domain suitability and speech/noise-proxy behavior remain validation questions.

## Leakage inspection and evaluation limits

Reference-name comparisons found no exact shared nonempty reference filenames across the seven published subsets. This does **not** rule out related utterances with renamed filenames, overlapping segments or repeated speakers. TRAIN_LIVE has only 495 distinct reference names for 1,020 degraded examples; VAL_LIVE has 102 for 200. TEST_P501 has four reference names for 240 rows. Related distortions must remain grouped.

Parsed `reader_<digits>` from DNS reference filenames: TRAIN_SIM has 1,599 distinct tokens, TRAIN_LIVE 486, VAL_SIM 341 and VAL_LIVE 102; all DNS rows parsed. TRAIN_SIM/LIVE share **484** reader tokens; VAL_SIM/LIVE share **101**. No token intersection was found between the combined DNS training and validation partitions. This supports the intended DNS partitioning but is only a filename-token check, not verified global speaker identity. Do not infer that the 2/1 unshared LIVE tokens are errors; source provenance requires further inspection.

AusTalk, UKIRE, TSP and test-subset speaker/session identities were not fully reconstructed; no decoded-audio duplicate search, cross-corpus overlap check or recording-offset comparison was run. There is no universal speaker/call field. A future split manifest needs source-specific identity parsing and grouping, especially across SIM/LIVE, before claiming speaker-disjoint evaluation. Do not randomly split clip rows or their frames.

The MOS labels can evaluate pooled clip scores and their correlation with human quality. They cannot validate each 10 ms p_t, trailing-window MOS, degradation onset, recovery delay or false alarms per hour. LIVE speech is replayed source material through calls, not continuous conversations; LIVETALK comprises short German conversation excerpts and limited speakers. New time-local annotations and longer continuous calls remain necessary. No classification metric substitutes for the approved MOS-correlation requirement. No predictive accuracy is claimed.

## Commands, checks and preservation

[commands.md](../../inspection/nisqa_bounded/commands.md) records the substantive commands and initial failed probes; the three retained Python inspection helpers provide exact acquisition/selection/analysis logic. They use standard-library modules only. No dependency was installed. Existing project files were checked against a pre-inspection SHA-256 manifest: all **72** remain byte-identical. The sole project addition is this report; no project file was modified or deleted. Inspection helpers/assets and recovery manifests were added outside the nested project, as itemized in the final inventory.

No GRU inference, training, quantization, RTL/testbench work, synthesis or physical implementation ran. Stop here. Recommend owner approval of the dataset subset, complete rights/provenance checks and split/frontend validation scope before any training. This inspection does not authorize another download or phase.
