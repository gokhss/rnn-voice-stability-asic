"""Resource counts from Yosys output, not technology area/timing/power."""
import json,collections
from pathlib import Path

def walk(mods,name,counts,resources):
    for ident,c in mods[name].get('cells',{}).items():
        if c['type'] in mods:walk(mods,c['type'],counts,resources)
        else:
            counts[c['type']]+=1
            if c['type'] in ('$mem','$mul','$div','$mod'):
                resources.append({'module':name,'cell':ident,'type':c['type'],'parameters':c['parameters'],'connections':c['connections'] if c['type']=='$mul' else {}})
result={}
for label,filename in [('rtlil','build/hardware_rtlil.json'),('generic','build/hardware_generic.json')]:
    mods=json.loads(Path(filename).read_text())['modules'];counts=collections.Counter();resources=[]
    walk(mods,'voice_stability_top',counts,resources)
    result[label]={'primitive_counts':dict(counts),'total_primitive_cells':sum(counts.values())}
    if label=='rtlil':
        result[label]['memories']=[{'name':x['module']+'/'+x['cell'],**{k:x['parameters'][k] for k in ['WIDTH','SIZE','RD_PORTS','WR_PORTS']}} for x in resources if x['type']=='$mem']
        muls=[]
        for x in resources:
            if x['type']!='$mul':continue
            muls.append({'module':x['module'],'a_width':x['parameters']['A_WIDTH'],'b_width':x['parameters']['B_WIDTH'],'constant_operand':any(all(isinstance(bit,str) for bit in x['connections'][p]) for p in ['A','B'])})
        result[label]['multipliers']=muls
        assert sum(not x['constant_operand'] for x in muls)==1
        assert not counts['$div'] and not counts['$mod']
    else:
        result[label]['sequential_bits']=sum(v for k,v in counts.items() if k.startswith('$_DFF'))
        assert not counts['$mem'] and not counts['$div'] and not counts['$mul']
        assert not any('LATCH' in k for k in counts)
result['limitations']='Baseline 8/16 generic Boolean synthesis, no Liberty mapping, PDK timing, area or power.'
Path('reports/hardware/resources.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
