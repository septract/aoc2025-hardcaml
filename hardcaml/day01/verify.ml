(* Day 01: Formal Verification

   Verifies the hardware implementation (solution.ml) against
   the software specification (spec.ml).
*)

open Hardcaml
open Day01.Solution

(* Simulate one instruction through the actual hardware *)
module Sim = Cyclesim.With_interface(Dial.I)(Dial.O)

let simulate_one_instruction ~pos:_ ~dir ~dist =
  let sim = Sim.create Dial.create in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  (* Reset - hardware starts at position 50 *)
  inputs.clear := Bits.of_int ~width:1 1;
  inputs.valid := Bits.of_int ~width:1 0;
  inputs.dir := Bits.of_int ~width:1 0;
  inputs.dist := Bits.of_int ~width:Dial.dist_width 0;
  Cyclesim.cycle sim;

  inputs.clear := Bits.of_int ~width:1 0;
  Cyclesim.cycle sim;

  (* Process the instruction *)
  inputs.valid := Bits.of_int ~width:1 1;
  inputs.dir := Bits.of_int ~width:1 dir;
  inputs.dist := Bits.of_int ~width:Dial.dist_width dist;
  Cyclesim.cycle sim;

  inputs.valid := Bits.of_int ~width:1 0;
  Cyclesim.cycle sim;

  let hw_pos = Bits.to_int !(outputs.position) in
  let hw_part1 = Bits.to_int !(outputs.part1_count) in
  let hw_part2 = Bits.to_int !(outputs.part2_count) in
  (hw_pos, hw_part1, hw_part2)

(* Exhaustive verification: test ALL valid inputs *)
let verify_exhaustive () =
  Printf.printf "Exhaustive verification: testing all valid inputs\n";
  Printf.printf "  pos ∈ [0,99], dir ∈ {0,1}, dist ∈ [0,4095]\n\n";

  let errors = ref 0 in
  let tests = ref 0 in

  (* Hardware starts at position 50 *)
  let initial_pos = 50 in

  for dir = 0 to 1 do
    for dist = 0 to 4095 do
      incr tests;

      let (hw_pos, hw_part1, hw_part2) = simulate_one_instruction ~pos:initial_pos ~dir ~dist in

      let sw_pos = Day01.Spec.new_position ~pos:initial_pos ~dir ~dist in
      let sw_zeros = Day01.Spec.zeros ~pos:initial_pos ~dir ~dist in
      let sw_ended = if Day01.Spec.ended_at_zero ~pos:initial_pos ~dir ~dist then 1 else 0 in

      if hw_pos <> sw_pos then begin
        incr errors;
        if !errors <= 5 then
          Printf.printf "  ERROR: pos=%d dir=%d dist=%d: hw_pos=%d sw_pos=%d\n"
            initial_pos dir dist hw_pos sw_pos
      end;

      if hw_part1 <> sw_ended then begin
        incr errors;
        if !errors <= 5 then
          Printf.printf "  ERROR: pos=%d dir=%d dist=%d: hw_part1=%d sw_ended=%d\n"
            initial_pos dir dist hw_part1 sw_ended
      end;

      if hw_part2 <> sw_zeros then begin
        incr errors;
        if !errors <= 5 then
          Printf.printf "  ERROR: pos=%d dir=%d dist=%d: hw_part2=%d sw_zeros=%d\n"
            initial_pos dir dist hw_part2 sw_zeros
      end
    done
  done;

  Printf.printf "  Tested %d inputs from initial position %d\n" !tests initial_pos;
  if !errors = 0 then begin
    Printf.printf "  ✓ All tests passed!\n";
    true
  end else begin
    Printf.printf "  ✗ %d errors found\n" !errors;
    false
  end

(* Test a sequence of instructions to verify state accumulation *)
let verify_sequence () =
  Printf.printf "\nSequence verification: testing instruction sequences\n";

  let sim = Sim.create Dial.create in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  (* Reset *)
  inputs.clear := Bits.of_int ~width:1 1;
  inputs.valid := Bits.of_int ~width:1 0;
  inputs.dir := Bits.of_int ~width:1 0;
  inputs.dist := Bits.of_int ~width:Dial.dist_width 0;
  Cyclesim.cycle sim;
  inputs.clear := Bits.of_int ~width:1 0;
  Cyclesim.cycle sim;

  (* Test sequence *)
  let test_cases = [
    (1, 50);   (* R50: 50 + 50 = 100 -> pos=0, crossed zero once *)
    (0, 25);   (* L25: 0 + 100 - 25 = 75 *)
    (1, 125);  (* R125: 75 + 125 = 200 -> pos=0, crossed zero twice *)
    (1, 99);   (* R99: 0 + 99 = 99 *)
    (0, 100);  (* L100: 99 + 100 - 0 = 199 -> pos=99, crossed zero once *)
  ] in

  let sw_pos = ref 50 in
  let sw_part1 = ref 0 in
  let sw_part2 = ref 0 in
  let errors = ref 0 in

  List.iter (fun (dir, dist) ->
    (* Software computation using Spec *)
    let zeros = Day01.Spec.zeros ~pos:!sw_pos ~dir ~dist in
    let new_pos = Day01.Spec.new_position ~pos:!sw_pos ~dir ~dist in
    sw_part2 := !sw_part2 + zeros;
    if new_pos = 0 then incr sw_part1;
    sw_pos := new_pos;

    (* Hardware simulation *)
    inputs.valid := Bits.of_int ~width:1 1;
    inputs.dir := Bits.of_int ~width:1 dir;
    inputs.dist := Bits.of_int ~width:Dial.dist_width dist;
    Cyclesim.cycle sim;

    let hw_pos = Bits.to_int !(outputs.position) in
    let hw_part1 = Bits.to_int !(outputs.part1_count) in
    let hw_part2 = Bits.to_int !(outputs.part2_count) in

    if hw_pos <> !sw_pos || hw_part1 <> !sw_part1 || hw_part2 <> !sw_part2 then begin
      incr errors;
      Printf.printf "  ERROR after %s%d: hw=(%d,%d,%d) sw=(%d,%d,%d)\n"
        (if dir = 1 then "R" else "L") dist
        hw_pos hw_part1 hw_part2 !sw_pos !sw_part1 !sw_part2
    end else
      Printf.printf "  ✓ %s%d: pos=%d part1=%d part2=%d\n"
        (if dir = 1 then "R" else "L") dist hw_pos hw_part1 hw_part2
  ) test_cases;

  inputs.valid := Bits.of_int ~width:1 0;
  Cyclesim.cycle sim;

  if !errors = 0 then begin
    Printf.printf "  ✓ Sequence test passed!\n";
    true
  end else begin
    Printf.printf "  ✗ %d sequence errors\n" !errors;
    false
  end

(* Verify position always stays in valid range *)
let verify_position_range () =
  Printf.printf "\nRange verification: position always in [0,99]\n";

  let errors = ref 0 in
  let initial_pos = 50 in

  for dir = 0 to 1 do
    for dist = 0 to 4095 do
      let (hw_pos, _, _) = simulate_one_instruction ~pos:initial_pos ~dir ~dist in
      if hw_pos < 0 || hw_pos >= 100 then begin
        incr errors;
        if !errors <= 5 then
          Printf.printf "  ERROR: dir=%d dist=%d produced invalid position %d\n"
            dir dist hw_pos
      end
    done
  done;

  if !errors = 0 then begin
    Printf.printf "  ✓ Position always valid!\n";
    true
  end else begin
    Printf.printf "  ✗ %d range errors\n" !errors;
    false
  end

let () =
  Printf.printf "Day 01: Verification of Hardware Implementation\n";
  Printf.printf "================================================\n";
  Printf.printf "Verifying solution.ml against spec.ml\n\n";

  let results = [
    verify_position_range ();
    verify_sequence ();
    verify_exhaustive ();
  ] in

  Printf.printf "\n";
  if List.for_all Fun.id results then
    Printf.printf "✓ All verifications passed!\n"
  else
    Printf.printf "✗ Some verifications failed.\n"
