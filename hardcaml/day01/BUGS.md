# Day 01 Bug Report

## BUG-001: 12-bit overflow in count_zeros_left

**Found by**: Formal verification (verify.ml)

**Severity**: Medium (doesn't affect puzzle input, but incorrect for edge cases)

### Description

In `count_zeros_left`, the intermediate calculation `diff = dist - pos + 100` overflows 12 bits for large `dist` values.

### Reproduction

```
pos = 50, dir = 0 (LEFT), dist = 4046
Expected zeros: (4046 - 50 + 100) / 100 = 40
Actual zeros: 0
```

### Root Cause

```ocaml
let diff = dist -: pos_ext +: hundred in  (* all 12-bit values *)
```

When `dist - pos + 100 > 4095`, the result wraps around. For example:
- `4046 - 50 + 100 = 4096`
- In 12 bits: `4096 mod 4096 = 0`

### Affected Range

Overflow occurs when `dist > pos + 3995`. For:
- pos=0: dist > 3995
- pos=50: dist > 4045
- pos=99: dist > 4094

### Fix

Widen intermediate calculation to 13+ bits before division:

```ocaml
let diff = uresize dist 13 -: uresize pos_ext 13 +: of_int ~width:13 100 in
```

### Status

**Not fixed** - puzzle input doesn't trigger this case, produces correct answer (Part 2: 6379).
