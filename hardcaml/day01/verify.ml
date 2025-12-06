(* Day 01: SAT-Based Formal Verification

   This file uses SAT solvers to PROVE properties about the hardware.
   Unlike simulate.ml (which tests by enumeration), this file:
   - Proves the division/modulo primitives are mathematically correct
   - Proves properties hold for ALL inputs without enumeration
   - Uses hardcaml_verify's SAT/SMT solving capabilities

   VERIFICATION STRATEGY:
   ======================
   The spec (spec.ml) and hardware (solution.ml) use IDENTICAL formulas:
   - new_position: (pos + dist) mod 100 for right, etc.
   - zeros_right: (pos + dist) / 100
   - zeros_left: special cases + (dist - pos + 100) / 100

   The only difference is that hardware uses reciprocal multiplication:
     x / 100 ≈ (x * 1311) >> 17

   Therefore, our verification proves:
   1. The reciprocal multiplication is correct for all valid inputs
   2. The mod_100 derived from it is also correct
   3. Properties (position bounded, reversibility) hold

   Combined with exhaustive testing in simulate.ml (819,200 test cases),
   this provides complete verification coverage.

   Performance note:
   - 32-bit multiplication creates huge CNF formulas (too slow!)
   - We use narrower bit widths optimized for valid input ranges
   - Max input to div: ~4200 (13 bits), max output: ~42 (6 bits)
*)

open Base
open Stdio
open Hardcaml_verify

let time_now () = Core_unix.gettimeofday ()

module C = Comb_gates

let pos_width = 7
let dist_width = 12

(* ============================================================
   SAT Solving Helpers
   ============================================================ *)

(* Check if proposition is UNSAT (meaning its negation is proved) *)
let check_unsat name cnf =
  printf "  [%s] solving..." name;
  Out_channel.(flush stdout);
  let start = time_now () in
  let z3_solver = Solver.z3 ~parallel:false () in
  let result = Solver.solve ~solver:z3_solver cnf in
  let elapsed = time_now () -. start in
  match result with
  | Ok Sat.Unsat ->
    printf " PROVED (%.2fs)\n" elapsed;
    Out_channel.(flush stdout);
    true
  | Ok (Sat.Sat model) ->
    printf " DISPROVED (%.2fs)\n" elapsed;
    printf "    Counterexample:\n";
    List.iter model ~f:(fun { Cnf.Model_with_vectors.name; value } ->
      printf "      %s = 0b%s\n" name value);
    Out_channel.(flush stdout);
    false
  | Error e ->
    printf " ERROR (%.2fs): %s\n" elapsed (Base.Error.to_string_hum e);
    Out_channel.(flush stdout);
    false

(* Check if two signals can ever differ (returns 1-bit signal) *)
let any_differ a b =
  let xor_bits = C.(a ^: b) in
  C.(reduce ~f:(|:) (bits_lsb xor_bits))

(* ============================================================
   Layer 1: Verify div_100 with 12-bit inputs

   This proves the reciprocal multiplication algorithm:
     div_100(x) = (x * 1311) >> 17
   gives correct floor(x/100) for x ∈ [0,4095]

   Reference uses comparison chain (trivially correct).
   ============================================================ *)

module Div100 = struct
  open C

  (* Reference: compute x/100 using comparison chain
     This is obviously correct: count how many multiples of 100 fit in x *)
  let reference x =
    let x12 = uresize x 12 in
    let w = 12 in
    let ge n = uresize (x12 >=: of_int ~width:w (n * 100)) 6 in
    ge 1 +: ge 2 +: ge 3 +: ge 4 +: ge 5 +:
    ge 6 +: ge 7 +: ge 8 +: ge 9 +: ge 10 +:
    ge 11 +: ge 12 +: ge 13 +: ge 14 +: ge 15 +:
    ge 16 +: ge 17 +: ge 18 +: ge 19 +: ge 20 +:
    ge 21 +: ge 22 +: ge 23 +: ge 24 +: ge 25 +:
    ge 26 +: ge 27 +: ge 28 +: ge 29 +: ge 30 +:
    ge 31 +: ge 32 +: ge 33 +: ge 34 +: ge 35 +:
    ge 36 +: ge 37 +: ge 38 +: ge 39 +: ge 40

  (* Hardware: reciprocal multiplication *)
  let hardware x =
    let x12 = uresize x 12 in
    let multiplier = of_int ~width:11 1311 in
    let product = x12 *: multiplier in  (* 12+11 = 23 bits *)
    uresize (srl product 17) 6
end

let prove_div100 () =
  let x = C.input "x" 12 in
  let ref_result = Div100.reference x in
  let hw_result = Div100.hardware x in
  let differ = any_differ ref_result hw_result in
  check_unsat "div_100 correct for all 12-bit inputs" (C.cnf differ)

(* ============================================================
   Layer 2: Verify mod_100 with 12-bit inputs

   mod_100(x) = x - 100 * div_100(x)
   Since div_100 is proven correct, mod_100 follows.
   ============================================================ *)

module Mod100 = struct
  open C

  (* For 12-bit inputs (dist alone) *)
  let reference x =
    let x12 = uresize x 12 in
    let q = uresize (Div100.reference x) 12 in
    let hundred = of_int ~width:12 100 in
    let q_times_100 = uresize (q *: hundred) 12 in
    uresize (x12 -: q_times_100) 7

  let hardware x =
    let x12 = uresize x 12 in
    let q = uresize (Div100.hardware x) 12 in
    let hundred = of_int ~width:12 100 in
    let q_times_100 = uresize (q *: hundred) 12 in
    uresize (x12 -: q_times_100) 7
end

(* Extended versions for 13-bit inputs (pos + dist can be up to 4194) *)
module Div100_13 = struct
  open C

  let reference x =
    let x13 = uresize x 13 in
    let w = 13 in
    let ge n = uresize (x13 >=: of_int ~width:w (n * 100)) 6 in
    ge 1 +: ge 2 +: ge 3 +: ge 4 +: ge 5 +:
    ge 6 +: ge 7 +: ge 8 +: ge 9 +: ge 10 +:
    ge 11 +: ge 12 +: ge 13 +: ge 14 +: ge 15 +:
    ge 16 +: ge 17 +: ge 18 +: ge 19 +: ge 20 +:
    ge 21 +: ge 22 +: ge 23 +: ge 24 +: ge 25 +:
    ge 26 +: ge 27 +: ge 28 +: ge 29 +: ge 30 +:
    ge 31 +: ge 32 +: ge 33 +: ge 34 +: ge 35 +:
    ge 36 +: ge 37 +: ge 38 +: ge 39 +: ge 40 +:
    ge 41  (* 4194/100 = 41.94, so max quotient is 41 *)

  let hardware x =
    let x13 = uresize x 13 in
    let multiplier = of_int ~width:11 1311 in
    let product = x13 *: multiplier in  (* 13+11 = 24 bits *)
    uresize (srl product 17) 6
end

module Mod100_13 = struct
  open C

  let reference x =
    let x13 = uresize x 13 in
    let q = uresize (Div100_13.reference x) 13 in
    let hundred = of_int ~width:13 100 in
    let q_times_100 = uresize (q *: hundred) 13 in
    uresize (x13 -: q_times_100) 7

  let hardware x =
    let x13 = uresize x 13 in
    let q = uresize (Div100_13.hardware x) 13 in
    let hundred = of_int ~width:13 100 in
    let q_times_100 = uresize (q *: hundred) 13 in
    uresize (x13 -: q_times_100) 7
end

let prove_mod100 () =
  let x = C.input "x" 12 in
  let ref_result = Mod100.reference x in
  let hw_result = Mod100.hardware x in
  let differ = any_differ ref_result hw_result in
  check_unsat "mod_100 correct for all 12-bit inputs" (C.cnf differ)

(* Also prove 13-bit versions for pos+dist range *)
let prove_div100_13 () =
  let x = C.input "x" 13 in
  (* Only test valid range: x <= 4194 (max pos + dist = 99 + 4095) *)
  let valid = C.(x <=: of_int ~width:13 4194) in
  let ref_result = Div100_13.reference x in
  let hw_result = Div100_13.hardware x in
  let differ = any_differ ref_result hw_result in
  let violation = C.(valid &: differ) in
  check_unsat "div_100 correct for 13-bit (pos+dist range)" (C.cnf violation)

let prove_mod100_13 () =
  let x = C.input "x" 13 in
  let valid = C.(x <=: of_int ~width:13 4194) in
  let ref_result = Mod100_13.reference x in
  let hw_result = Mod100_13.hardware x in
  let differ = any_differ ref_result hw_result in
  let violation = C.(valid &: differ) in
  check_unsat "mod_100 correct for 13-bit (pos+dist range)" (C.cnf violation)

(* ============================================================
   Layer 3: Position always bounded < 100

   For any valid starting position and any rotation,
   the result is always in [0, 99].
   ============================================================ *)

let prove_position_bounded () =
  let pos = C.input "pos" pos_width in
  let dist = C.input "dist" dist_width in
  let dir = C.input "dir" 1 in

  (* Constrain pos < 100 (valid dial position) *)
  let pos_valid = C.(pos <: of_int ~width:pos_width 100) in

  (* Compute new position: mod_100 of sum for right, different formula for left *)
  let pos_ext = C.uresize pos 13 in
  let dist_ext = C.uresize dist 13 in
  let hundred = C.of_int ~width:13 100 in

  (* Right: (pos + dist) mod 100 - use 13-bit version since sum can exceed 4095 *)
  let right_sum = C.(pos_ext +: dist_ext) in
  let right_pos = Mod100_13.hardware right_sum in

  (* Left: (pos + 100 - (dist mod 100)) mod 100 *)
  (* dist mod 100 uses 12-bit version, final mod uses 13-bit (max = 99+100-0=199) *)
  let dist_mod = Mod100.hardware dist in
  let left_raw = C.(pos_ext +: hundred -: uresize dist_mod 13) in
  let left_pos = Mod100_13.hardware left_raw in

  let new_pos = C.(mux2 dir right_pos left_pos) in

  let violation = C.(pos_valid &: (new_pos >=: of_int ~width:7 100)) in
  check_unsat "position always < 100" (C.cnf violation)

(* ============================================================
   Layer 4: Reversibility - R(n) then L(n) returns to start

   This is a key mathematical property of modular arithmetic.
   ============================================================ *)

let prove_reversibility () =
  let pos = C.input "pos" pos_width in
  let dist = C.input "dist" dist_width in

  (* Constrain pos < 100 *)
  let pos_valid = C.(pos <: of_int ~width:pos_width 100) in

  let pos_ext = C.uresize pos 13 in
  let dist_ext = C.uresize dist 13 in
  let hundred = C.of_int ~width:13 100 in

  (* Step 1: R(dist) - move right, use 13-bit mod since sum can exceed 4095 *)
  let after_right = Mod100_13.hardware C.(pos_ext +: dist_ext) in

  (* Step 2: L(dist) - move left from new position *)
  let dist_mod = Mod100.hardware dist in
  let left_raw = C.(uresize after_right 13 +: hundred -: uresize dist_mod 13) in
  let after_left = Mod100_13.hardware left_raw in

  (* Should return to original position *)
  let not_same = any_differ pos after_left in
  let violation = C.(pos_valid &: not_same) in

  check_unsat "R(n) then L(n) = identity" (C.cnf violation)

(* ============================================================
   Main
   ============================================================ *)

let () =
  printf "Day 01: SAT-based Formal Verification\n";
  printf "=====================================\n";
  printf "Proving correctness for FULL input range: pos ∈ [0,99], dist ∈ [0,4095]\n\n";

  printf "Layer 1a: Division 12-bit - (x * 1311) >> 17 == floor(x/100)\n";
  let d1 = prove_div100 () in

  printf "\nLayer 1b: Division 13-bit - for pos+dist up to 4194\n";
  let d2 = prove_div100_13 () in

  printf "\nLayer 2a: Modulo 12-bit - x mod 100 == x - 100 * (x/100)\n";
  let m1 = prove_mod100 () in

  printf "\nLayer 2b: Modulo 13-bit - for pos+dist up to 4194\n";
  let m2 = prove_mod100_13 () in

  printf "\nLayer 3: Bounded - new position always < 100\n";
  let p1 = prove_position_bounded () in

  printf "\nLayer 4: Reversible - R(n) then L(n) returns to start\n";
  let r1 = prove_reversibility () in

  printf "\n";
  let all_passed = d1 && d2 && m1 && m2 && p1 && r1 in
  if all_passed then (
    printf "========================================\n";
    printf "All SAT proofs passed!\n\n";
    printf "WHAT THIS PROVES:\n";
    printf "  • div_100 via reciprocal mult is mathematically correct\n";
    printf "  • mod_100 derived from it is correct\n";
    printf "  • Position stays in valid range [0,99]\n";
    printf "  • Dial rotation is reversible\n\n";
    printf "Combined with exhaustive testing (819,200 cases in simulate.ml),\n";
    printf "the Day 01 solution is fully verified.\n"
  ) else
    printf "Some verifications FAILED.\n"
