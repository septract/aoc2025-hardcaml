# Project Context

Advent of Code 2025 solutions implemented as synthesizable hardware designs using Hardcaml (OCaml HDL).

## Environment

- **opam switch**: `advent-fpga` (OCaml 5.2.0)
- **Key packages**: hardcaml, hardcaml_verify, hardcaml_waveterm, ppx_hardcaml

## Build Commands

```bash
# Build all solutions
opam exec --switch=advent-fpga -- dune build

# Run simulation and exhaustive testing
opam exec --switch=advent-fpga -- dune exec hardcaml/day01/simulate.exe -- common/test_vectors/day01.txt

# Run SAT-based formal verification
opam exec --switch=advent-fpga -- dune exec hardcaml/day01/verify.exe
```

## Project Structure

```
hardcaml/dayNN/
├── solution.ml   # Hardware implementation (synthesizable RTL)
├── spec.ml       # Software specification (plain OCaml)
├── simulate.ml   # Simulation + exhaustive TESTING
├── verify.ml     # SAT-based formal PROOFS
└── BUGS.md       # Issues found by testing/verification
```

## File Roles — READ THIS CAREFULLY

### solution.ml — Hardware Implementation
- Pure synthesizable RTL using Hardcaml
- No simulation, no I/O, no side effects
- **This is what gets synthesized to real hardware**

### spec.ml — Software Specification
- Plain OCaml defining correct behavior
- No Hardcaml — just standard OCaml int/bool operations
- **Single source of truth for "what is correct"**

### simulate.ml — Simulation and Testing (ENUMERATION)
**THIS IS TESTING, NOT VERIFICATION**
- Runs hardware simulation using Cyclesim
- Tests specific inputs from test vectors
- Exhaustive testing by looping through input space
- Compares hw output to spec output
- **Finds bugs by trying inputs one at a time**

### verify.ml — Formal Verification (SAT SOLVING)
**THIS IS PROOF, NOT TESTING**
- Uses SAT/SMT solvers via hardcaml_verify
- Proves properties hold for ALL inputs simultaneously
- Equivalence checking: prove hw circuit == spec circuit
- Property checking: prove invariants (e.g., pos < 100)
- **Proves correctness without enumeration**

## Key Distinction

| | simulate.ml | verify.ml |
|---|---|---|
| Method | Loop through inputs | SAT solving |
| Proves | Nothing (just tests) | Mathematical proof |
| Scales | O(n) in input space | Handles large spaces |
| Finds | Bugs that occur in tested inputs | All possible bugs |

## SAT Verification Patterns (hardcaml_verify)

### Core Pattern: Prove by Checking UNSAT
To prove property P holds for ALL inputs, check if NOT(P) is satisfiable:
- **UNSAT** → No counterexample exists → Property PROVED
- **SAT** → Found counterexample → Property DISPROVED

```ocaml
(* Prove: output < 100 for all inputs *)
let violation = C.(output >=: of_int ~width:7 100) in
match Solver.solve (C.cnf violation) with
| Ok Sat.Unsat -> (* PROVED! *)
| Ok (Sat.Sat model) -> (* Found counterexample *)
```

### Use Comb_gates, Not Signal
`hardcaml_verify` requires `Comb_gates` for SAT conversion:
```ocaml
module C = Comb_gates
let x = C.input "x" 12  (* NOT Signal.input *)
```

### Layered Verification Strategy
**Problem**: Large multiplications create huge CNF formulas (too slow).

**Solution**: Verify in layers, proving smaller components first:
1. **Layer 1**: Prove div_100 correct using comparison-chain reference
2. **Layer 2**: Prove mod_100 correct (uses proven div_100)
3. **Layer 3**: Prove mux/control logic
4. **Layer 4**: Prove full circuit properties

### Comparison-Chain Reference for Division
Instead of verifying `(x * 1311) >> 17` directly against true division, use a comparison chain that's easier for SAT:
```ocaml
(* Reference: floor(x/100) via comparisons *)
let div_100_reference x =
  let ge n = uresize (x >=: of_int ~width:12 (n * 100)) 6 in
  ge 1 +: ge 2 +: ge 3 +: ... +: ge 40
```

### Narrow Bit Widths
Use minimum widths for valid input ranges to reduce CNF size:
- pos: 0-99 → 7 bits
- dist: 0-4095 → 12 bits
- pos + dist: 0-4194 → 13 bits

### Solver Selection
```ocaml
let result = Solver.solve ~solver:(Solver.z3 ~parallel:false ()) cnf
(* or: Solver.minisat, Solver.picosat *)
```

## Design Principles

1. **Spec first** — Write spec.ml before solution.ml
2. **All computation in hardware** — Goal is synthesizable RTL
3. **Test exhaustively** — simulate.ml tests all reachable inputs
4. **Prove formally** — verify.ml proves properties via SAT
5. **Document bugs** — Track issues in BUGS.md

## Project Scope

R&D project exploring AI-assisted hardware design. **Not for contest submission.**

## References

- [Hardcaml docs](https://github.com/janestreet/hardcaml/blob/master/docs/index.md)
- [hardcaml_verify](https://ocaml.org/p/hardcaml_verify/)
- [Challenge details](https://blog.janestreet.com/advent-of-fpga-challenge-2025/)
