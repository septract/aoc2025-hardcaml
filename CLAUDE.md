# Project Context

Advent of Code 2025 solutions implemented as synthesizable hardware designs using Hardcaml (OCaml HDL).

## Environment

- **opam switch**: `advent-fpga` (OCaml 5.2.0)
- **Key packages**: hardcaml, hardcaml_verify, hardcaml_waveterm, ppx_hardcaml

## Build Commands

```bash
# Build all solutions
opam exec --switch=advent-fpga -- dune build

# Run all tests (simulation + verification)
opam exec --switch=advent-fpga -- dune runtest

# Run specific day simulation
opam exec --switch=advent-fpga -- dune exec hardcaml/day01/simulate.exe -- common/test_vectors/day01.txt

# Run specific day verification
opam exec --switch=advent-fpga -- dune exec hardcaml/day01/verify.exe
```

## Project Structure

```
advent-of-fpga-2025/
├── dune-project              # Root dune config
├── dune                      # Test runner rules
├── hardcaml/
│   └── dayNN/
│       ├── dune              # Build config
│       ├── solution.ml       # Hardware implementation (synthesizable RTL)
│       ├── spec.ml           # Software specification (plain OCaml)
│       ├── simulate.ml       # Runs hardware simulation against test vectors
│       ├── verify.ml         # Proves hardware matches spec
│       └── BUGS.md           # Known issues found by verification
└── common/
    └── test_vectors/
        └── dayNN.txt         # Puzzle input
```

## File Roles

### solution.ml — Hardware Implementation
- Contains the synthesizable RTL design
- Pure Hardcaml signals and combinational/sequential logic
- No simulation code, no I/O, no side effects
- **This is what gets synthesized to real hardware**

### spec.ml — Software Specification
- Defines correct behavior in **plain, readable OCaml**
- No Hardcaml dependencies - just standard OCaml
- Single source of truth for "what is correct"
- Both simulate.ml and verify.ml import this

### simulate.ml — Simulation Runner
- Runs hardware simulation using Cyclesim
- Compares hardware output against spec.ml
- Handles file I/O and test vector parsing
- Entry point: `dune exec hardcaml/dayNN/simulate.exe`

### verify.ml — Formal Verification
- Exhaustively tests hardware against spec
- Reports any discrepancies between hw and sw
- Can use SAT-based verification for larger spaces
- Entry point: `dune exec hardcaml/dayNN/verify.exe`

## Design Principles

1. **Spec first** — Write spec.ml before solution.ml. Define what "correct" means in plain OCaml.
2. **All computation in hardware** — The goal is synthesizable RTL, not software running on an FPGA.
3. **Verify exhaustively** — Use verify.ml to prove hardware matches spec across all inputs.
4. **Document bugs** — When verification finds discrepancies, document them in BUGS.md.

## Project Scope

R&D project exploring AI-assisted hardware design using AoC puzzles. **Not for contest submission.**

## References

- [Hardcaml docs](https://github.com/janestreet/hardcaml/blob/master/docs/index.md)
- [hardcaml_verify](https://ocaml.org/p/hardcaml_verify/)
- [Challenge details](https://blog.janestreet.com/advent-of-fpga-challenge-2025/)
