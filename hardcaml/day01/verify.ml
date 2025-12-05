(* Day 01: SAT-Based Formal Verification

   This file uses SAT solvers to PROVE properties about the hardware.
   Unlike simulate.ml (which tests by enumeration), this file:
   - Proves equivalence between hardware and spec circuits
   - Proves properties hold for ALL inputs without enumeration
   - Uses hardcaml_verify's SAT/SMT solving capabilities

   TODO: Implement SAT-based verification using hardcaml_verify.
   Current status: Placeholder - actual SAT verification not yet implemented.
*)

open Hardcaml

let () =
  Printf.printf "Day 01: SAT-Based Formal Verification\n";
  Printf.printf "=====================================\n\n";
  Printf.printf "Status: NOT YET IMPLEMENTED\n\n";
  Printf.printf "Planned verifications:\n";
  Printf.printf "  1. Equivalence: hardware position calc == spec position calc\n";
  Printf.printf "  2. Equivalence: hardware zero count == spec zero count\n";
  Printf.printf "  3. Property: position output is always < 100\n";
  Printf.printf "  4. Property: R(n) then L(n) returns to same position\n";
  Printf.printf "\n";
  Printf.printf "For now, use simulate.ml for exhaustive testing.\n";
  ignore (Signal.of_int ~width:1 0)  (* Suppress unused open warning *)
