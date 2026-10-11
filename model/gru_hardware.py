"""Explicit INT8 F7 / INT16 F12 hardware oracle. Original references unchanged.
Untrained deterministic fixtures only. No QAT or prediction-accuracy assertion.
"""
import argparse
import json
import math
import random
from pathlib import Path
try:
    from .quantize import sat, rounded
    from .generate_weights import weight as old_weight, bias as old_bias
except ImportError:
    from quantize import sat, rounded
    from generate_weights import weight as old_weight, bias as old_bias

SIG = tuple(int(math.floor(4096/(1+math.exp(-k/64))+.5)) for k in range(513))
TAN = tuple(int(math.floor(4096*math.tanh(k/64)+.5)) for k in range(256))+(4096,)

def sigmoid(x):
    y=SIG[min(512,(abs(x)+32)>>6)]
    return 4096-y if x<0 else y

def tanh(x):
    y=TAN[min(256,(abs(x)+32)>>6)]
    return -y if x<0 else y

def image(inputs,hidden,stress=False):
    # Explicit old-Q12 -> F7 conversion; not byte truncation.
    w=[rounded(old_weight(g,j,k),5) for g in range(3) for j in range(hidden) for k in range(inputs+hidden)]
    # Untrained head fixture equivalent to the old mean for H=16/32.
    w += [rounded(4096//hidden,5)]*hidden
    b=[old_bias(g,j)<<7 for g in range(3) for j in range(hidden)]+[0]
    if stress:
        w=[(-128 if k%2 else 127) for k in range(len(w))]
        b=[(-2147483648 if k%2 else 2147483647) for k in range(len(b))]
    assert all(-128<=v<=127 for v in w)
    return w+b

class HardwareGRU:
    def __init__(self,inputs=8,hidden=16,parameters=None,activation_functions=None):
        if not 8<=inputs<=16 or not 16<=hidden<=32: raise ValueError('dimensions')
        self.inputs,self.hidden=inputs,hidden
        self.sigmoid,self.tanh=(sigmoid,tanh) if activation_functions is None else activation_functions
        self.m=3*hidden*(inputs+hidden)+hidden
        self.params=list(image(inputs,hidden) if parameters is None else parameters)
        if len(self.params)!=self.m+3*hidden+1: raise ValueError('image length')
        if any(not -128<=w<=127 for w in self.params[:self.m]): raise ValueError('INT8 weights')
        if any(not -(1<<31)<=b<(1<<31) for b in self.params[self.m:]): raise ValueError('INT32 bias')
        self.flush()
    def flush(self):
        self.h=[0]*self.hidden; self.average=None; self.alert=False
    def step(self,x,k=4,low=32768,high=39321):
        if len(x)!=self.inputs or any(not -32768<=v<=32767 for v in x): raise ValueError('features')
        if not 0<=k<=8 or not 0<=low<high<=65535: raise ValueError('configuration')
        h=self.h[:]; gates=[]; clipped=False
        def requant(v,shift):
            nonlocal clipped
            y=rounded(v,shift); clipped|=not -32768<=y<=32767
            return sat(y)
        q=None
        for g in range(3):
            operands=list(x)+(h if g<2 else q)
            gate=[]
            for j in range(self.hidden):
                off=(g*self.hidden+j)*(self.inputs+self.hidden)
                acc=self.params[self.m+g*self.hidden+j]+sum(a*b for a,b in zip(operands,self.params[off:off+len(operands)]))
                assert -(1<<39)<=acc<(1<<39)
                gate.append((self.tanh if g==2 else self.sigmoid)(requant(acc,7)))
            gates.append(gate)
            if g==1:q=[requant(a*b,12) for a,b in zip(gate,h)]
        z,r,n=gates
        self.h=[requant(a*b+(4096-a)*c,12) for a,b,c in zip(z,h,n)]
        score=min(65535,self.sigmoid(requant(self.params[-1]+sum(a*b for a,b in zip(self.h,self.params[self.m-self.hidden:self.m])),7))<<4)
        if self.average is None:self.average=score
        else:
            delta=score-self.average
            self.average=max(0,min(65535,self.average+(delta if k==0 else rounded(delta,k))))
        if not self.alert and self.average<low:self.alert=True
        elif self.alert and self.average>high:self.alert=False
        return {'z':z,'r':r,'q':q,'n':n,'h':self.h[:],'score':score,'average':self.average,'alert':int(self.alert),'sat':int(clipped)}

def pack(values):return ''.join(f'{v&65535:04x}' for v in reversed(values))

def generate(out,inputs,hidden,count,stress=False,flush_every=97):
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    model=HardwareGRU(inputs,hidden,image(inputs,hidden,stress));rng=random.Random(17)
    (out/'image.mem').write_text('\n'.join(f'{v&0xffffffff:08x}' for v in model.params)+'\n')
    lines=[]
    for frame in range(count):
        # Flush every 97 frames exercises fresh call boundaries independently of reset.
        flush=frame==0 or (flush_every>0 and frame%flush_every==0)
        if flush:model.flush()
        x=([0]*inputs if frame==0 else [32767]*inputs if frame==1 else [-32768]*inputs if frame==2 else [rng.randint(-32768,32767) for _ in range(inputs)])
        a=model.step(x)
        lines.append(pack(x)+''.join(pack(a[t]) for t in ['z','r','q','n','h'])+f"{a['score']:04x}{a['average']:04x}{a['alert']:02x}{a['sat']:02x}{int(flush):02x}")
    (out/'vectors.mem').write_text('\n'.join(lines)+'\n')
    (out/'activations.mem').write_text('\n'.join(f'{sigmoid(x):04x}{tanh(x)&65535:04x}' for x in range(-32768,32768))+'\n')
    return {'inputs':inputs,'hidden':hidden,'frames':count,'stress':stress,'flush_every':flush_every,'sigmoid_max_error':max(abs(sigmoid(x)/4096-1/(1+math.exp(-x/4096))) for x in range(-32768,32768)),'tanh_max_error':max(abs(tanh(x)/4096-math.tanh(x/4096)) for x in range(-32768,32768))}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',default='build/hardware');p.add_argument('--inputs',type=int,default=8);p.add_argument('--hidden',type=int,default=16);p.add_argument('--frames',type=int,default=256);p.add_argument('--stress',action='store_true');p.add_argument('--flush-every',type=int,default=97);a=p.parse_args()
    result=generate(a.out,a.inputs,a.hidden,a.frames,a.stress,a.flush_every)
    Path(a.out,'generation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
