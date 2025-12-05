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
