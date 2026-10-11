# Phase 4 execution report — stopped at data-readiness gate

Status: **blocked, not completed**. The current authorization defines Phase 4 as floating-point training/evaluation, superseding the earlier phase numbering for this run. No quantization or later phase was started. The user's instruction 2 requires documenting the blocker and stopping if local data/dependencies prevent a defensible experiment; that condition was met before frontend or training implementation.

## Executed results

From `rnn-voice-stability-asic/`:

```
python3 -B -m unittest discover -s tests -v
```

Exit **0**: **21 tests passed**, zero failures/skips, reported runtime 0.860 seconds. These are the existing floating GRU equation/state/validation tests, not voice-quality tests. No new tests were added because execution stopped at the data gate.

Read the existing GRU, Phase 2/3 reports, NISQA inspection report, local acquisition manifest and recorded commands. Reused their schema and license findings; did not repeat the remote acquisition or corpus audit. A local availability/hash/dependency check exited **0** and confirmed:

* 14,432 corpus metadata rows, but only **six corresponding degraded audio clips** locally.
* Six distinct DNS reader tokens, all from NISQA_TRAIN_LIVE.
* One additional clean reference WAV, which is not a seventh independently labeled example.
* No locally acquired official validation/test audio. A workspace WAV search found exactly these seven files.
* All **14 acquired members** still match their saved SHA-256 hashes.
* Python 3.10.12; NumPy available. SciPy, PyTorch, TensorFlow, JAX, autograd and soundfile are not discoverable in this interpreter. No packages installed.

`git status --short --branch` in the project returned **128**, with “not a git repository”; no clean-tree/commit claim is made. The initial combined read command returned 0 from its last command, which does not mean Git succeeded.

## Exact blocker and permitted use

The existing [NISQA inspection report](nisqa_bounded_inspection.md) and retained TRAIN_LIVE README establish research-use permission under source terms. The present training authorization is not blocked merely because the earlier download was for inspection. **The blocker is the amount and selection of the available audio.**

The six examples were deliberately chosen as minimum/middle/maximum MOS within each of Skype and phone conditions, not as a population-representative experimental sample:

| Reader token | Call type | Supplied MOS |
|---|---|---|
| 01326 | phone | 1.0 |
| 04891 | Skype | 1.0 |
| 11431 | Skype | 2.4 |
| 10929 | Skype | 4.2 |
| 10362 | phone | 4.25 |
| 08463 | phone | 2.0 |

It is technically possible to partition six reader groups, but a 4/1/1 split would leave one validation and one test example, for which Pearson/Spearman correlation is undefined. A 2/2/2 split would train on two clips and make two-point nonconstant correlations trivially ±1. Neither supports a defensible generalization assessment or reliable validation checkpoint selection. More frames from these same clips do not create more independent MOS labels. The clean reference cannot be relabeled as a new example. Metadata for absent audio cannot substitute for training samples.

These files can support frontend/software smoke tests in another explicitly scoped task; they cannot meet the requested quality-training experiment. No arbitrary universal minimum corpus size is asserted. A materially larger, provenance-grouped and appropriately sampled audio set with independent validation/test groups is needed.

The existing NumPy GRU implements inference without gradients or an optimizer. No autodiff training framework is installed. This is an additional implementation constraint, not a claim that NumPy training is impossible: a tested NumPy backward pass could be implemented under a suitable scope. Resolving it alone would not resolve the data blocker. No dependency installation or further download was attempted.

## Requested experiment outputs

| Output | Actual status |
|---|---|
| Local labeled sample/group count | 6 clips / 6 reader tokens |
| Assigned train/validation/test counts | Not assigned; no split manifest created |
| Causal frontend and tests | Not implemented after stop condition |
| Training-only normalization | Not fitted |
| Training history / selected epoch | No epochs executed / not applicable |
| Validation metrics | Not measured |
| Held-out test MAE/RMSE/Pearson/Spearman | Not measured; no test evaluation |
| Training-mean baseline metrics | Not measured; no training partition |
| Trained checkpoint | None |

Not-measured results are not zero, failures of a trained model, or computed NaNs. The undefined-correlation discussion above concerns hypothetical tiny splits, not a performed evaluation. No model inference on NISQA, predictive accuracy or frame-level accuracy is claimed.

## Commands and reproduction

Run the test command above from the project. The local availability check can be reproduced from the workspace root without network access:

```bash
python3 -B - <<'PY'
import csv, hashlib, importlib.util, json
from pathlib import Path
r = Path('inspection/nisqa_bounded')
m = json.loads((r/'acquisition_manifest.json').read_text())
for item in m['extracted_members']:
    assert hashlib.sha256((r/'members'/item['member']).read_bytes()).hexdigest() == item['sha256']
rows = list(csv.DictReader((r/'members/NISQA_Corpus/NISQA_corpus_file.csv').open()))
local = [x for x in rows if (r/'members/NISQA_Corpus'/x['filepath_deg']).is_file()]
print('metadata rows:', len(rows), 'local labeled clips:', len(local))
print({n: importlib.util.find_spec(n) is not None
       for n in ['numpy', 'scipy', 'torch', 'tensorflow', 'jax', 'autograd', 'soundfile']})
PY
```

The executed expanded check also recorded reader tokens, all workspace WAV paths, Git status and each local MOS in [preflight.json](../../recovery/phase4-20261010T220451Z/preflight.json). No training reproduction command exists because no training script/run was created. No placeholder checkpoint, split or fabricated training artifact is delivered.

## Preservation and stop

Only this report was added inside the project. No existing project file was modified or deleted. Pre-edit hashes for all **73** starting project files and the preflight evidence are retained in `recovery/phase4-20261010T220451Z/`; all original files passed the final hash comparison. Earlier recovery archives and local inspection assets were preserved. RTL, hardware weights, quantization code, existing tests/testbenches, model, previous reports and implementation scripts remain unchanged.

Stopped as required. Resuming a defensible experiment needs separately authorized additional bounded audio acquisition (not the full corpus) or suitable owner-provided local data, plus an approved training dependency or tested NumPy-training implementation. No acquisition, installation or Phase 5 is authorized by this report.
