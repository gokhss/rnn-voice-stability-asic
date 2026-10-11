"""Collect evidence paths without interpreting unvalidated vendor report formats."""
import json
import re
from pathlib import Path

root=Path(__file__).resolve().parent.parent
checks={
 'simulation': 'build/sim_pass', 'lint': 'build/lint_pass',
 'synthesis':'build/voice_stability_top_mapped.v',
 'sta':'reports/sta_summary.rpt', 'pnr':'build/voice_stability_top.enc',
 'gds':'gds/voice_stability_top.gds', 'signoff_wrappers':'build/signoff_complete'}
result={'stages':{k:('ARTIFACT PRESENT — inspect report' if (root/v).exists() else 'NOT RUN / BLOCKED') for k,v in checks.items()},
 'metrics':{k:'NOT MEASURED' for k in ['clock_frequency','cell_area','cell_count','power','WNS','TNS','setup_violations','hold_violations','processing_latency_cycles','frame_throughput','DRC_violations','LVS_status']},
 'baseline':{'inputs':8,'hidden':8,'precision_bits':16,'clock_target_MHz':50},
 'evidence':{k:v for k,v in checks.items() if (root/v).exists()}}
model=root/'reports/model.json'
if model.exists(): result['activation_errors']=json.loads(model.read_text())
log=root/'reports/tb_voice_stability_top.log'
if (root/'build/sim_pass').exists() and log.exists():
    match=re.search(r'MEASURED score latency cycles=(\d+)',log.read_text())
    if match: result['metrics']['processing_latency_cycles']=int(match.group(1))
# Preserve vendor reports as evidence. WNS/TNS/cell/power parsing is deliberately
# not guessed across tool versions; copy reviewed measurements into README.
(root/'reports').mkdir(exist_ok=True)
(root/'reports/qor.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(result,indent=2,ensure_ascii=False))
