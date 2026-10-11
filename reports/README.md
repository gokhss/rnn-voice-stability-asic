# Reports and retained evidence

| Location | Contents | Publication treatment |
|---|---|---|
| [hardware/](hardware/README.md) | Reviewed checkpoint summaries, original change manifest and evidence extracts | Explicitly allowed by .gitignore |
| [hardware/finalization/](hardware/finalization/) | Logs, resource summaries, hashes and manifests from the earlier finalization run | Retained portable evidence; not a new organization-time run |
| Other files and subdirectories here | Original simulation logs and laboratory synthesis/physical reports | Preserved locally and ignored pending publication review |

All existing logs and reports remain intact. An ignored file is still present on disk; ignore rules only control normal Git discovery. Do not force-add raw vendor output without reviewing institutional identifiers, local paths and technology redistribution restrictions.

Other retained local artifacts remain under build/, waveforms/, cadence/, fv/, timingReports/, xcelium.d/, gds/ and .cadence/. Previously archived loose files remain in .local_archive/. Vendor directories were not relocated because their databases can contain embedded paths. The [audit](../docs/repository_audit.md) explains the earlier archive decisions.

Results are scoped by the [verification guide](../docs/verification.md) and [limitations](../docs/limitations.md). Generic counts do not establish physical area or power, and the presence of a lab report does not establish complete timing closure or signoff. No lint, simulation, tests, synthesis or PPA analysis was performed for the subsequent organization-only update.
