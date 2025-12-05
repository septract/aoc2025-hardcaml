# Project Context

Advent of Code 2025 solutions implemented as synthesizable hardware designs using Hardcaml (OCaml HDL).

## Environment

- **opam switch**: `advent-fpga` (OCaml 5.2.0)
- **Key packages**: hardcaml, hardcaml_verify, hardcaml_waveterm, ppx_hardcaml

## Build Commands

```bash
# Build all solutions
opam exec --switch=advent-fpga -- dune build

# Run all tests
opam exec --switch=advent-fpga -- dune runtest

# Run specific day
opam exec --switch=advent-fpga -- dune exec hardcaml/day01/solution.exe -- common/test_vectors/day01.txt
```

## Project Structure & Conventions

```
advent-of-fpga-2025/
├── dune-project              # Root dune config
├── dune                      # Test runner rules
├── hardcaml/
│   └── dayNN/
│       ├── dune              # (executable (name solution) ...)
│       └── solution.ml       # Hardware implementation + testbench
└── common/
    └── test_vectors/
        └── dayNN.txt         # Puzzle input
```

**Naming conventions:**
- Each day's solution lives in `hardcaml/dayNN/solution.ml`
- Test vectors go in `common/test_vectors/dayNN.txt`
- The executable is always named `solution` in dune

## Design Requirements

- **ALL computation must be in hardware** — the goal is synthesizable RTL, not software simulation
- Software reference implementations are OK for verification, but the actual solution must be hardware
- Hardcaml lacks division/modulo primitives — implement using:
  - **Multiplication by reciprocal**: `x / D ≈ (x * M) >> S` where M and S are chosen for accuracy
  - Lookup tables for small domains
  - Iterative subtraction for variable divisors
  - Bit manipulation for powers of 2

## Hardcaml Patterns

**Register with custom reset value:**
```ocaml
(* Don't use ~clear in Reg_spec if you need non-zero reset *)
let spec = Reg_spec.create ~clock:i.clock () in
let reg = reg_fb ~width:8 ~f:(fun r ->
  mux2 i.clear (of_int ~width:8 50)  (* reset to 50, not 0 *)
    (mux2 i.valid new_value r)
) spec
```

**Division by constant (e.g., 100):**
```ocaml
(* x / 100 ≈ (x * 1311) >> 17, accurate for x < 5000 *)
let div_by_100 x =
  let x_wide = uresize x 32 in
  srl (x_wide *: of_int ~width:32 1311) 17

let mod_100 x =
  let q = div_by_100 x in
  x -: (q *: of_int ~width:32 100)
```

**Interface modules:**
```ocaml
module I = struct
  type 'a t = { clock : 'a; data : 'a [@bits 8] } [@@deriving hardcaml]
end
```

## Formal Verification

Use **hardcaml_verify** for SAT-based equivalence checking and bounded model checking:
```ocaml
open Hardcaml_verify
(* Prove two implementations are equivalent *)
Sat.prove_equivalence impl1 impl2
```

## Verilog Export

```ocaml
let circuit = Circuit.create_exn ~name:"day01" [output]
Rtl.print Verilog.output circuit
```

## Project Scope

R&D project exploring AI-assisted hardware design using AoC puzzles. **Not for contest submission.**

## References

- [Hardcaml docs](https://github.com/janestreet/hardcaml/blob/master/docs/index.md)
- [hardcaml_verify](https://ocaml.org/p/hardcaml_verify/)
- [Challenge details](https://blog.janestreet.com/advent-of-fpga-challenge-2025/)
