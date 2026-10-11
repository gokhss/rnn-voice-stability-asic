"""Untrained, synthetic numerical comparison, never a task-accuracy measurement."""
import json,random
from pathlib import Path
import numpy as np
import gru_reference as legacy
from gru_hardware import HardwareGRU,image
from gru_float import FloatGRU,GRUParameters

def main():
    I,H=8,16; p=image(I,H); M=3*H*(I+H)+H
    tensors={}
    for g,name in enumerate(['z','r','n']):
        rows=np.asarray(p[g*H*(I+H):(g+1)*H*(I+H)],dtype=float).reshape(H,I+H)/128
        tensors['W_'+name]=rows[:,:I];tensors['U_'+name]=rows[:,I:]
        tensors['b_'+name]=np.asarray(p[M+g*H:M+(g+1)*H],dtype=float)/(1<<19)
    tensors['W_s']=np.asarray(p[M-H:M],dtype=float).reshape(1,H)/128
    tensors['b_s']=p[-1]/(1<<19)
    floating=FloatGRU(GRUParameters(I,H,**tensors))
    old=legacy.GRU(I,H); hw=HardwareGRU(I,H); converted=HardwareGRU(I,H,activation_functions=(legacy.sigmoid,legacy.tanh))
    rng=random.Random(17); diffs={k:[] for k in ['old_Q12_vs_F7_old_PWL','old_Q12_vs_hardware_ROM','hardware_vs_float_same_F7_parameters']}
    for i in range(1024):
        if i%97==0:
            old.h=[0]*H; hw.flush();converted.flush();floating.start_call()
        x=[rng.randint(-32768,32767) for _ in range(I)]
        a=old.step(x)/65536; b=converted.step(x)['score']/65536;c=hw.step(x)['score']/65536;d=floating.step(np.asarray(x)/4096)
        for k,v in zip(diffs,[abs(a-b),abs(a-c),abs(c-d)]):diffs[k].append(v)
    result={'frames':1024,'inputs':I,'hidden':H,'seed':17,'parameters':'untrained deterministic converted prototype; equal-mean head for H16','meaning':'numerical only; not voice accuracy or QAT','differences':{k:{'mean_absolute_score_error':sum(v)/len(v),'max_absolute_score_error':max(v)} for k,v in diffs.items()}}
    Path('reports/hardware/format_comparison.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
