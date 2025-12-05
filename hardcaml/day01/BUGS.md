# Day 01 Bug Report

## BUG-001: 12-bit overflow in arithmetic operations

**Found by**: Formal verification (verify.ml)

**Severity**: Medium (didn't affect puzzle input, but incorrect for edge cases)

**Status**: Fixed

### Description

Multiple arithmetic operations overflowed 12 bits for large `dist` values near the maximum (4095).

### Affected Functions

1. **count_zeros_left**: `diff = dist - pos + 100` overflowed
2. **count_zeros_right**: `sum = pos + dist` overflowed
3. **calc_new_position**: `right_sum = pos + dist` overflowed

### Reproduction

```
pos = 50, dir = 1 (RIGHT), dist = 4046
Expected position: (50 + 4046) mod 100 = 96
Actual position: 0  (because 4096 mod 4096 = 0 in 12 bits)

pos = 50, dir = 0 (LEFT), dist = 4046
Expected zeros: (4046 - 50 + 100) / 100 = 40
Actual zeros: 0  (because 4096 mod 4096 = 0 in 12 bits)
```

### Root Cause

All intermediate sums used 12-bit arithmetic, which overflows at 4096:
- `pos + dist` max = 99 + 4095 = 4194 > 4095
- `dist - pos + 100` max = 4095 - 0 + 100 = 4195 > 4095

### Fix

Widen all intermediate calculations to 13 bits:

```ocaml
(* Before *)
let sum = pos_ext +: dist in

(* After *)
let sum = uresize pos 13 +: uresize dist 13 in
```

### Verification

After fix, exhaustive verification passes for all 8192 test cases (2 directions × 4096 distances).
