"""Independent integer oracle and deterministic regression vector generator."""
import argparse
import json
import math
from pathlib import Path
from quantize import ONE, sat, rounded, mul
from generate_weights import weight, bias

TABLE = [0,194,488,1102,2048,2994,3608,3902,4096]

def sigmoid(x):
    if x <= -4*ONE:
        return 0
    if x >= 4*ONE:
        return ONE
    seg, rem = divmod(x+4*ONE, ONE)
    return TABLE[seg] + ((TABLE[seg+1]-TABLE[seg])*rem)//ONE

def tanh(x):
    return 2*sigmoid(2*x)-ONE

class GRU:
    def __init__(self, inputs=8, hidden=8):
        self.inputs, self.hidden = inputs, hidden
        self.h = [0]*hidden

    def step(self, x):
        assert len(x) == self.inputs
        gates = []
        for g in range(3):
            recurrent = self.h if g != 2 else [mul(r,h) for r,h in zip(gates[1],self.h)]
            operands = x+recurrent
            sums = [sat(rounded(bias(g,j)*ONE + sum(weight(g,j,k)*v for k,v in enumerate(operands)))) for j in range(self.hidden)]
            gates.append([(tanh(v) if g==2 else sigmoid(v)) for v in sums])
        z, r, n = gates
        self.h = [sat(rounded(a*b+(ONE-a)*c)) for a,b,c in zip(z,self.h,n)]
        projection = sat(rounded(sum(self.h)*(ONE//self.hidden)))
        return min(65535, sigmoid(projection)*16)

class Average:
    def __init__(self):
        self.values = []
        self.window = None
    def step(self, score, window):
        window = max(1,min(16,window))
        if window != self.window:
            self.values = []
            self.window = window
        self.values = (self.values+[score])[-window:]
        return sum(self.values)//len(self.values)

def pack(values):
    return ''.join('{:04x}'.format(v & 65535) for v in reversed(values))

def vectors(path, count=128):
    model, avg = GRU(), Average()
    seed = 1
    lines = []
    for i in range(count):
        x = []
        for j in range(8):
            seed = (1664525*seed+1013904223) & 0xffffffff
            x.append((seed >> 16)-32768)
        if i == 0: x = [0]*8
        if i == 1: x = [32767]*8
        if i == 2: x = [-32768]*8
        win = 16 if i < 64 else (1 if i < 80 else 7)
        threshold = 65535 if i % 4 == 0 else (0 if i % 4 == 1 else 32768)
        score = model.step(x)
        mean = avg.step(score, win)
        # 128 input + 128 hidden + 16 score + 16 mean + 16 threshold + 8 window + 8 alert = 320 bits.
        lines.append(pack(x)+pack(model.h)+'{:04x}{:04x}{:04x}{:02x}{:02x}'.format(score,mean,threshold,win,int(mean<threshold)))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text('\n'.join(lines)+'\n')

def checks():
    assert rounded(2048)==1 and rounded(-2048)==-1
    assert mul(-32768,-32768)==32767
    assert sat(40000)==32767 and sat(-40000)==-32768
    assert sigmoid(-16384)==0 and sigmoid(16384)==4096
    assert tanh(-32768)==-4096 and tanh(32767)==4096
    a = Average()
    assert [a.step(v,3) for v in [3,6,12,15]] == [3,4,7,11]
    assert a.step(99,1)==99
    model = GRU()
    model.step([4096]*8)
    first = list(model.h)
    model.step([4096]*8)
    assert model.h != first
    errors = {'sigmoid_max_abs_error':0.0,'tanh_max_abs_error':0.0}
    for x in range(-32768,32768):
        real=x/4096.0
        errors['sigmoid_max_abs_error']=max(errors['sigmoid_max_abs_error'],abs(sigmoid(x)/4096.0-1/(1+math.exp(-real))))
        errors['tanh_max_abs_error']=max(errors['tanh_max_abs_error'],abs(tanh(x)/4096.0-math.tanh(real)))
    assert errors['sigmoid_max_abs_error'] < 0.03
    assert errors['tanh_max_abs_error'] < 0.06
    return errors

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--vectors',default='tb/test_vectors.mem')
    ap.add_argument('--check',action='store_true')
    args=ap.parse_args()
    vectors(args.vectors)
    if args.check:
        result=checks()
        Path('reports').mkdir(exist_ok=True)
        Path('reports/model.json').write_text(json.dumps(result,indent=2)+'\n')
        print('PASS: integer model checks; exhaustive activation error grid',result)
if __name__=='__main__':
    main()
