# Phase 3 proposed target and feature contract

Status: engineering proposal for owner review; no frontend, dataset, labels or training implemented. PS-01 requires a bounded score and declared correlation with reference quality. The approved [GRU mathematics](gru_mathematical_specification.md) remains unchanged. Dataset evidence is in [dataset audit](dataset_audit.md).

## Primary target: continuous quality regression

For an eligible clip j with human overall MOS m_j on a verified 1–5 scale, define y_j=(m_j−1)/4. High values mean better perceived quality. Reject missing/out-of-range/unidentified-scale labels; do not silently clip them or relabel another scale as MOS. Keep rating count, dispersion and study identity where supplied. This normalized score is not a probability of stability and is not a measurement of statistical variance in voice quality.

The initial weakly supervised contract is explicit:

```
p_j,t = sigmoid(W_s h_j,t + b_s)    # approved causal GRU/head
p_bar_j = sum_t d_j,t * p_j,t / sum_t d_j,t
loss = mean_j (p_bar_j - y_j)^2
predicted_MOS_j = 1 + 4*p_bar_j
```

Here d is the valid hop duration, normally 10 ms; padding receives zero weight and cannot update state. All complete real frames, including silence and startup, participate. Each clip has equal loss weight, irrespective of length. This offline pooling/loss is a floating training/evaluation operation outside the accelerator; it does not introduce a hardware divider or replace the runtime shift EMA. Clip pooling and hardware EMA are different quantities and must be reported separately.

Reset hidden/frontend state at each independent recording/call, retain state across consecutive frames, and do not reset at arbitrary training chunks. With only clip MOS, p_t is an unsupervised temporal contribution to clip quality: many per-frame trajectories have the same mean. Never repeat clip MOS as supposedly measured 10 ms ground truth, infer alert timing accuracy from clip correlation, or claim an instantaneous MOS predictor has been validated.

The deployment objective is quality tracking over time, not prediction of future events. A proposed future temporal validation target is human MOS for a trailing 4-second received-audio window, annotated every 1 second on continuous calls (window boundaries and listener protocol recorded). Compare mean p over each labeled window to its normalized MOS; separately evaluate EMA/alert transitions. These durations are proposed engineering choices, not existing data or validated optimal resolution. Call startup shorter than four seconds is a separate evaluation stratum. If the owner requires a different alert latency, annotation cadence/window must change before collection. Human labels are needed to validate perceptual event timing; packet events alone are insufficient.

## Alternatives and acceptance metric

Binary stable/degraded labels could train cross-entropy on a sigmoid probability, but that changes its meaning and discards MOS resolution. Classification accuracy alone cannot satisfy PS-01 correlation. Recommend retaining regression and deriving alert decisions as secondary evaluations from independently labeled quality windows.

Propose a pre-registered primary gate of **Pearson r > 0.80** between predicted and human MOS on an untouched, group-disjoint evaluation set, with sample/group counts and group-bootstrap 95% confidence interval. This is a proposed team threshold, not an observed result or a PS-01 numeric mandate. Owner confirmation is required before experimentation. Also report Spearman rho, MAE/RMSE in MOS units, calibration, per-corpus and per-condition results. A pass on clip MOS supports only clip-level correlation. Continuous monitoring still requires the temporal evaluation above. A constant-label or constant-prediction set has undefined correlation, not a pass. Test-set recalibration or resampling to improve the primary score is forbidden.

PESQ-derived labels are a separate optional surrogate requiring compatible reference/degraded pairs, a documented metric implementation/version and its use rights. Do not normalize raw PESQ as though it were human MOS; record raw versus mapped MOS-LQO and applicable scale. Do not claim teacher estimates are human ratings. Human MOS avoids needing a reference at runtime. The [ITU P.862 record](https://www.itu.int/rec/T-REC-P.862/en) identifies PESQ as an objective telephony assessment method; no PESQ tool was installed or executed here.

## Feature profiles and timing

**Proposed initial A8:** eight audio-derived features, I=8/H=16, preserving the baseline dimensions. Jitter/loss are PS-01 example features, not eight individually mandated inputs. Their omission must be visible: A8 estimates received-audio quality without network telemetry. **Proposed T12:** A8 plus jitter, playout-loss fraction and two validity flags; I=12/H=16 remains within the approved configurable range but is a separately trained/model-versioned option requiring owner selection. No current model or architecture file was changed to select T12.

Frontend runs outside this RTL accelerator, on the host/DSP. Proposed mono decoded receiver audio at 16 kHz, PCM scaled by its format's full-scale value, preserving relative levels. Do not peak-normalize each clip. Use a documented causal resampler with known delay when needed; no offline zero-phase/future-sample processing. Narrowband audio upsampled to 16 kHz contains no new high-band information. Start with narrowband/wideband telephony; fullband corpora need separate domain analysis because discarded high-frequency information may influence their original MOS. Keep original labels attached to original audio, and document this information-loss risk.

At 16 kHz use trailing N=320-sample (20 ms) windows and HOP=160 samples (10 ms). First feature arrives after 20 ms; thereafter every 10 ms. Timestamp is window end in playout time. Only complete windows are emitted; drop the final incomplete hop and record its duration. No lookahead. Retain silence, speech gaps and decoded concealment output. Corrupt/missing PCM is an ingestion error, not fabricated silence. Frontend/transport delay and 20 ms initial buffering are additional to the accelerator's <1 ms feature-to-result target.

## Exact proposed A8 definitions

For each window, v is decoded amplitude, u=v−mean(v), E=mean(u²), epsilon=10^−12. Spectrum uses w[n]=0.5−0.5*cos(2*pi*n/(N−1)), and a 512-point real FFT of w*u padded with zeros. Let P[k]=c[k]*abs(FFT[k])², c=2 for interior positive-frequency bins and 1 at DC/Nyquist. Let B_i be sums in the bands below and B=sum_i B_i. These definitions are proposed, not existing extraction code or dataset metadata.

| Lane | Feature / units | Definition | Evidence category and limitations |
|---|---|---|---|
| 0 | Log energy, dB relative to full-scale squared | 10*log10(max(E,epsilon)) | Computed from received audio; retains level information |
| 1 | Causal SNR proxy, dB | Nhat=20th percentile of current and last 99 E values; 10*log10(max(E−Nhat,epsilon)/max(Nhat,epsilon)), clipped to [−20,60] | Computed audio proxy, not true SNR or simulator metadata; speech-heavy history biases estimate |
| 2 | Low-band fraction | B_0/max(B,epsilon), bins 0≤f<500 Hz | Computed audio |
| 3 | Lower-mid fraction | B_1/max(B,epsilon), 500≤f<1500 Hz | Computed audio |
| 4 | Upper-mid fraction | B_2/max(B,epsilon), 1500≤f<3000 Hz | Computed audio |
| 5 | High-band fraction | B_3/max(B,epsilon), 3000≤f≤8000 Hz | Computed audio; codec bandwidth strongly affects this |
| 6 | Zero-crossing fraction | Count of adjacent unequal (u[n]>0) booleans divided by N−1 | Computed audio; exactly zero counts as nonpositive |
| 7 | Spectral-change proxy | 0.5*sum_i abs(F_i,t−F_i,t−1), F_i=B_i/max(B,epsilon) | Computed audio; first frame value zero; not a measured packet-loss event |

For the percentile, sort the M available energies, q=0.2*(M−1), and linearly interpolate between floor(q) and ceil(q). At call start use the growing history including the current frame, not future samples; report the first 100 frames as startup separately as well as within overall metrics. Flush this history and previous spectral fractions at a new call. Four band fractions are partly redundant; retain this transparent first proposal and assess ablations on validation only. Zero-energy frames produce finite features by definition. The proxy clipping above is floating preprocessing, not INT16 saturation or a quantization experiment.

## T12 telemetry extension

| Lane | Feature | Source and proposed causal contract |
|---|---|---|
| 8 | Interarrival jitter, ms | Receiver RTP timestamps/arrival times; sample latest J at window end; log1p(J_ms/1 ms) before normalization |
| 9 | Playout-loss fraction, [0,1] | Duration of expected media missing/late at playout deadline divided by expected media duration during the latest 100 ms, or available shorter call-start history |
| 10 | Jitter-valid flag, 0/1 | 1 only with valid RTP clock mapping, at least two arrivals and latest arrival no older than 100 ms; otherwise 0 |
| 11 | Loss-valid flag, 0/1 | 1 only when receiver can account for expected media/deadlines throughout that interval and expected duration >0; otherwise 0 |

RTP jitter follows J_i=J_(i−1)+(|D_i|−J_(i−1))/16, with sender and receiver times converted to consistent units, computed in arrival order. This definition comes from [RFC 3550 §6.4.1](https://www.rfc-editor.org/rfc/rfc3550.html#section-6.4.1). The proposed playout-loss feature is deliberately different from RTCP reception loss: packets arriving after a deadline can still be counted as received by RTCP. Log decoder concealment, duplicates, reordering, clock-rate changes and expected media timing; do not equate intentional discontinuous transmission with loss.

Unavailable/stale telemetry becomes normalized zero **with its validity flag zero**, never a claim of measured zero jitter/loss. Fit telemetry normalization only on valid training observations. If none exist, T12 is not trainable as a validated telemetry model: use A8 instead. Corpus-wide impairment settings and true injected SNR are for stratification/diagnostics, not hidden privileged model inputs. No inspected dataset has verified fields matching lanes 8–11. Future simulation must log per-packet traces and actual playout consequences; real deployment must measure the same quantities. No simulation is authorized now.

## Normalization and frontend identity

For each continuous lane fit mean and standard deviation on training-only valid frames, giving each clip equal total weight. Transform (f−mu)/max(sigma,10^−6); leave binary flags unchanged. A constant training lane is mapped to zero and flagged in metadata. No numeric mu/sigma is invented in this phase. Do not use per-call future statistics or fit on validation/test. Do not silently clip normalized inputs to candidate hardware bounds: measure tail rates in later numeric work and approve a policy then.

A future manifest must bind sample rate, channel choice, resampler/version/delay, window/hop, bands, epsilon, proxy history/percentile, telemetry definitions/validity, normalization, feature order and model dimensions. The 10 ms cadence is part of model identity: changing to 20 ms requires a separately evaluated frontend/model and review of EMA time constant. Reject profile mismatches. The current float reference accepts already-prepared vectors and performs none of this preprocessing.
