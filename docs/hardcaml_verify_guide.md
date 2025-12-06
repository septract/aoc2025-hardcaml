# hardcaml_verify Guide

A practical guide to SAT-based formal verification with hardcaml_verify.

## Overview

hardcaml_verify provides tools to **prove** properties about Hardcaml circuits without exhaustive enumeration. It converts circuits to CNF (Conjunctive Normal Form) and uses SAT solvers to check satisfiability.

**Key insight**: To prove a property P holds for ALL inputs, we check if NOT(P) is satisfiable:
- If SAT: Found a counterexample - property does NOT hold
- If UNSAT: No counterexample exists - property HOLDS for all inputs

## Installation

```bash
opam install hardcaml_verify
```

Requires SAT solver binaries (minisat, picosat, or z3) in PATH.

## Core Modules

| Module | Purpose |
|--------|---------|
| `Comb_gates` | Build circuits using gate-level primitives |
| `Cnf` | Conjunctive Normal Form representation |
| `Solver` | Interface to SAT solvers |
| `Sat` | Result type (`Sat of model` or `Unsat`) |
| `Sec` | Sequential Equivalence Checking |
| `Nusmv` | NuSMV model checking integration |

## Approach 1: Low-Level CNF (Combinational Properties)

Use `Comb_gates` to build circuits, convert to CNF, and check satisfiability.

### Basic Pattern

```ocaml
open Hardcaml
open Hardcaml_verify

(* 1. Build circuit using Comb_gates (NOT regular Signal) *)
module C = Comb_gates

(* 2. Create inputs *)
let a = C.input "a" 8
let b = C.input "b" 8

(* 3. Build logic - Comb_gates supports all standard operations *)
let sum = C.(a +: b)
let overflow = C.(msb sum)

(* 4. Build the proposition to check *)
(* To prove "sum never overflows", check if "sum overflows" is satisfiable *)
let proposition = overflow  (* 1 bit: true if overflow *)

(* 5. Convert to CNF and solve *)
let cnf = C.cnf proposition
let result = Solver.solve cnf

(* 6. Interpret result *)
match result with
| Ok (Sat.Unsat) -> print_endline "PROVED: no overflow possible"
| Ok (Sat.Sat model) -> print_endline "DISPROVED: found counterexample"
| Error e -> print_endline ("Error: " ^ Error.to_string_hum e)
```

### Proving Equivalence

To prove `circuit1 == circuit2`, check if `circuit1 XOR circuit2` is satisfiable:

```ocaml
open Hardcaml_verify
module C = Comb_gates

let prove_equivalence ~name ~width f1 f2 =
  let input = C.input name width in
  let out1 = f1 input in
  let out2 = f2 input in
  (* If outputs differ for ANY bit, circuits aren't equivalent *)
  let differ = C.(out1 ^: out2) in
  let any_differ = C.(reduce ~f:(|:) differ) in
  let cnf = C.cnf any_differ in
  match Solver.solve cnf with
  | Ok Sat.Unsat -> `Equivalent
  | Ok (Sat.Sat _) -> `Not_equivalent
  | Error e -> `Error e

(* Example usage *)
let result = prove_equivalence ~name:"x" ~width:8
  (fun x -> C.(x +: x))           (* circuit 1: x + x *)
  (fun x -> C.(sll x 1))          (* circuit 2: x << 1 *)
```

### Proving Properties

To prove a property like "output < 100":

```ocaml
(* Prove: for all inputs, output < 100 *)
let prove_output_bounded f =
  let input = C.input "x" 12 in
  let output = f input in
  (* Check if output >= 100 is satisfiable *)
  let hundred = C.of_int ~width:(C.width output) 100 in
  let violation = C.(output >=: hundred) in
  let cnf = C.cnf violation in
  match Solver.solve cnf with
  | Ok Sat.Unsat -> `Proved  (* No violation possible *)
  | Ok (Sat.Sat _) -> `Disproved  (* Found input where output >= 100 *)
  | Error e -> `Error e
```

## Approach 2: Sequential Equivalence Checking (Sec)

For comparing full Hardcaml circuits (with inputs/outputs):

```ocaml
open Hardcaml
open Hardcaml_verify

(* Create two circuits *)
let circuit1 = Circuit.create_exn ~name:"c1" [output "y" (some_logic1 input)]
let circuit2 = Circuit.create_exn ~name:"c2" [output "y" (some_logic2 input)]

(* Compare them *)
let () =
  match Sec.create circuit1 circuit2 with
  | Error e -> print_endline ("Setup error: " ^ Error.to_string_hum e)
  | Ok sec ->
    match Sec.circuits_equivalent sec with
    | Error e -> print_endline ("Solve error: " ^ Error.to_string_hum e)
    | Ok Sat.Unsat -> print_endline "EQUIVALENT"
    | Ok (Sat.Sat model) ->
      print_endline "NOT EQUIVALENT - counterexample:";
      List.iter model ~f:(fun {name; value} ->
        Printf.printf "  %s = %s\n" name value)
```

### Important: Sec requires matching structure

`Sec.create` compares circuits by their **port names**. Both circuits must have:
- Same input port names
- Same output port names

## Choosing Solvers

```ocaml
(* Default: minisat *)
let result = Solver.solve cnf

(* Explicit solver selection *)
let result = Solver.solve ~solver:Solver.minisat cnf
let result = Solver.solve ~solver:Solver.picosat cnf
let result = Solver.solve ~solver:(Solver.z3 ~parallel:false ()) cnf
```

## Working with Models (Counterexamples)

When SAT returns a satisfying assignment:

```ocaml
match Solver.solve cnf with
| Ok (Sat.Sat model) ->
  (* model is a list of {name; value} records *)
  List.iter model ~f:(fun Cnf.Model_with_vectors.{name; value} ->
    Printf.printf "%s = 0b%s\n" name value)
| _ -> ()
```

## Converting Hardcaml Signals to Comb_gates

**Problem**: You can't directly use `Hardcaml.Signal.t` with `Comb_gates`.

**Solution**: Parameterize your circuit logic to work with any `Comb.S`:

```ocaml
(* Parameterized circuit - works with Signal.t OR Comb_gates.t *)
module Make_circuit (Comb : Hardcaml.Comb.S) = struct
  open Comb
  let f x = x +: x  (* works with any Comb.S implementation *)
end

(* For synthesis/simulation: use Signal *)
module Hw = Make_circuit(Hardcaml.Signal)
let hw_result = Hw.f (Signal.input "x" 8)

(* For verification: use Comb_gates *)
module Verify = Make_circuit(Comb_gates)
let verify_result = Verify.f (Comb_gates.input "x" 8)
```

## Common Pitfalls

### 1. Signals vs Comb_gates

```ocaml
(* WRONG: Can't mix Signal and Comb_gates *)
let s = Signal.input "x" 8
let c = Comb_gates.input "y" 8
let bad = Comb_gates.(s +: c)  (* Type error! *)

(* RIGHT: Use Comb_gates throughout *)
let a = Comb_gates.input "a" 8
let b = Comb_gates.input "b" 8
let good = Comb_gates.(a +: b)
```

### 2. Forgetting to negate for proofs

```ocaml
(* WRONG: This proves "property CAN be true" (useless) *)
let property = C.(x <: hundred)
let cnf = C.cnf property
(* SAT means: yes, x can be < 100. Not helpful! *)

(* RIGHT: Check if VIOLATION is satisfiable *)
let violation = C.(x >=: hundred)
let cnf = C.cnf violation
(* SAT means: found x >= 100. UNSAT means: x < 100 always holds *)
```

### 3. Width mismatches

```ocaml
(* Comb_gates is strict about widths *)
let a = C.input "a" 8
let b = C.input "b" 12
let bad = C.(a +: b)  (* Width error! *)

(* Use uresize/sresize *)
let good = C.(uresize a 12 +: b)
```

## Performance Tips

1. **Minimize bit widths** - SAT complexity grows with input space
2. **Use symmetry breaking** - Add constraints to eliminate equivalent solutions
3. **Try different solvers** - Z3 may be faster for some problems, minisat for others
4. **Break into subproblems** - Verify components separately when possible

## NuSMV Integration (LTL Properties)

For temporal logic properties (sequences, liveness, fairness):

```ocaml
(* TODO: NuSMV integration is more complex - requires external tool *)
(* See Hardcaml_verify.Nusmv module *)
```

## Limitations

1. **Combinational focus** - `Comb_gates`/`Sec` are best for combinational logic
2. **State explosion** - Sequential verification (BMC) limited by state space
3. **External solvers** - Requires minisat/picosat/z3 binaries installed
4. **No direct Signal conversion** - Must rebuild logic using `Comb_gates`

## References

- [hardcaml_verify on opam](https://ocaml.org/p/hardcaml_verify/)
- [hardcaml_verify GitHub](https://github.com/janestreet/hardcaml_verify)
- [Hardcaml paper (arXiv)](https://arxiv.org/html/2312.15035v1)
