"""Q4.12 arithmetic; nearest rounding, ties away from zero."""
F = 12
ONE = 1 << F

def sat(x):
    return max(-32768, min(32767, x))

def rounded(x, bits=F):
    half = 1 << (bits-1)
    return (x+half) >> bits if x >= 0 else -((-x+half) >> bits)

def mul(a, b):
    return sat(rounded(a*b))

def quantize(x):
    import math
    return sat(int(math.floor(x*ONE+0.5)) if x >= 0 else -int(math.floor(-x*ONE+0.5)))
