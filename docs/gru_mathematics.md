# Numerical contract

Let x be the accepted feature vector and h the previous frame state:

```
z = sigmoid(Wz*x + Uz*h + bz)
r = sigmoid(Wr*x + Ur*h + br)
n = tanh(Wn*x + Un*(r .* h) + bn)
h_next = z .* h + (1-z) .* n
score = sigmoid(sum(h_next)/HIDDEN)
```

This is the reset-before GRU variant. Every gate reads the complete old state;
all new neurons commit together. r*h is rounded and saturated to Q4.12 before
the candidate matrix multiplication. Gate MAC products are accumulated without
intermediate saturation in signed 40 bits. Bias enters as b*4096. Final MAC
conversion rounds nearest with exact ties away from zero, then saturates to
[-32768,32767]. h update adds two full-precision products before one rounding.
The score projection coefficient is floor(4096/HIDDEN); baseline HIDDEN=8
is exact. The unsigned score is min(65535, sigmoid_q12*16).

PWL sigmoid clamps outside [-4,4] and linearly connects Q4.12 values
[0,194,488,1102,2048,2994,3608,3902,4096] at integer inputs -4 through 4.
Tanh is 2*sigmoid(2*x)-1
with a widened argument. All interpolation divisions truncate nonnegative
values. model/gru_reference.py measures exhaustive input-grid approximation
errors against math.exp/math.tanh and writes the actual maxima to reports/.

The moving average divides the running sum by the number of valid samples
until the configured window fills, then by the window; division truncates.
Invalid cycles never enter the window. A window change clears history, and a
simultaneous valid sample is the first sample of the new window. Zero window
means one; values above MAX_WINDOW clamp. Alert uses strict less-than; equality
is healthy. No hysteresis. Alert is suppressed until the first average exists.
