"""Deterministic untrained coefficients; no random library/version dependence."""
import argparse
from pathlib import Path

def weight(gate, neuron, term):
    return ((gate*97 + neuron*53 + term*29 + 17) % 513)-256

def bias(gate, neuron):
    return ((gate*43 + neuron*31 + 11) % 257)-128

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', default='build/weights.tsv')
    args = ap.parse_args()
    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('w') as f:
        f.write('gate\tneuron\tterm\tq12\n')
        for g in range(3):
            for n in range(8):
                for t in range(16):
                    f.write('{}\t{}\t{}\t{}\n'.format(g,n,t,weight(g,n,t)))
                f.write('{}\t{}\tbias\t{}\n'.format(g,n,bias(g,n)))
if __name__ == '__main__':
    main()
