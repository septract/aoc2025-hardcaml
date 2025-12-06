(* Day 01: Simulation and Exhaustive Testing

   This file:
   - Runs hardware simulation against test vectors
   - Compares results to software spec
   - Performs exhaustive testing across input space

   This is NOT formal verification - it's testing by enumeration.
   For SAT-based formal proofs, see verify.ml.
*)

open Hardcaml
open Day01.Solution

(* ============================================================
   Hardware Simulation
   ============================================================ *)

module Sim = Cyclesim.With_interface(Dial.I)(Dial.O)

let create_sim () = Sim.create Dial.create

let reset_sim sim =
  let (i : Bits.t ref Dial.I.t) = Cyclesim.inputs sim in
  i.clear := Bits.of_int ~width:1 1;
  i.valid := Bits.of_int ~width:1 0;
  i.dir := Bits.of_int ~width:1 0;
  i.dist := Bits.of_int ~width:Dial.dist_width 0;
  Cyclesim.cycle sim;
  i.clear := Bits.of_int ~width:1 0;
  Cyclesim.cycle sim

let run_instruction sim ~dir ~dist =
  let (i : Bits.t ref Dial.I.t) = Cyclesim.inputs sim in
  i.valid := Bits.of_int ~width:1 1;
  i.dir := Bits.of_int ~width:1 dir;
  i.dist := Bits.of_int ~width:Dial.dist_width dist;
  Cyclesim.cycle sim;
  i.valid := Bits.of_int ~width:1 0

let read_outputs sim =
  let (o : Bits.t ref Dial.O.t) = Cyclesim.outputs sim in
  let pos = Bits.to_int !(o.position) in
  let part1 = Bits.to_int !(o.part1_count) in
  let part2 = Bits.to_int !(o.part2_count) in
  (pos, part1, part2)

(* ============================================================
   Test Vector Simulation
   ============================================================ *)

let parse_instruction line =
  let line = String.trim line in
  if String.length line < 2 then None
  else
    let dir_char = line.[0] in
    let dist_str = String.sub line 1 (String.length line - 1) in
    try
      let dir = if dir_char = 'R' then 1 else 0 in
      let dist = int_of_string dist_str in
      Some (dir, dist)
    with _ -> None

let read_instructions filename =
  let ic = open_in filename in
  let rec read_lines acc =
    try
      let line = input_line ic in
      match parse_instruction line with
      | Some instr -> read_lines (instr :: acc)
      | None -> read_lines acc
    with End_of_file ->
      close_in ic;
      List.rev acc
  in
  read_lines []

let simulate_test_vector filename =
  Printf.printf "Test Vector Simulation\n";
  Printf.printf "----------------------\n";
  Printf.printf "Reading: %s\n" filename;

  let instructions = read_instructions filename in
  Printf.printf "Loaded %d instructions\n\n" (List.length instructions);

  (* Software reference *)
  let (sw_part1, sw_part2) = Day01.Spec.solve instructions in
  Printf.printf "Software (spec.ml):\n";
  Printf.printf "  Part 1: %d\n" sw_part1;
  Printf.printf "  Part 2: %d\n\n" sw_part2;

  (* Hardware simulation *)
  let sim = create_sim () in
  reset_sim sim;

  List.iter (fun (dir, dist) ->
    run_instruction sim ~dir ~dist
  ) instructions;

  let (hw_pos, hw_part1, hw_part2) = read_outputs sim in
  Printf.printf "Hardware (solution.ml):\n";
  Printf.printf "  Part 1: %d\n" hw_part1;
  Printf.printf "  Part 2: %d\n" hw_part2;
  Printf.printf "  Final position: %d\n\n" hw_pos;

  if sw_part1 = hw_part1 && sw_part2 = hw_part2 then begin
    Printf.printf "  ✓ Hardware matches software!\n";
    true
  end else begin
    Printf.printf "  ✗ MISMATCH detected.\n";
    false
  end

(* ============================================================
   Exhaustive Testing (NOT formal verification)
   ============================================================ *)

(* Instantiate combinational logic with Bits for direct testing *)
module Comb_bits = Dial.Make_comb(Bits)

(* Test combinational logic directly - allows arbitrary starting position *)
let test_comb_logic ~pos ~dir ~dist =
  let open Bits in
  let pos_bits = of_int ~width:Dial.pos_width pos in
  let dir_bits = of_int ~width:1 dir in
  let dist_bits = of_int ~width:Dial.dist_width dist in
  let (new_pos, part1_inc, part2_inc) =
    Comb_bits.process_instruction ~pos:pos_bits ~dir:dir_bits ~dist:dist_bits
  in
  (to_int new_pos, to_int part1_inc, to_int part2_inc)

let test_exhaustive_from_pos50 () =
  Printf.printf "\nExhaustive Testing (from pos=50, sequential sim)\n";
  Printf.printf "-------------------------------------------------\n";
  Printf.printf "Testing all 8192 combinations: dir ∈ {0,1}, dist ∈ [0,4095]\n";

  let sim = create_sim () in
  let errors = ref 0 in
  let initial_pos = 50 in

  for dir = 0 to 1 do
    for dist = 0 to 4095 do
      reset_sim sim;
      run_instruction sim ~dir ~dist;
      let (hw_pos, hw_part1, hw_part2) = read_outputs sim in

      let sw_pos = Day01.Spec.new_position ~pos:initial_pos ~dir ~dist in
      let sw_zeros = Day01.Spec.zeros ~pos:initial_pos ~dir ~dist in
      let sw_ended = if Day01.Spec.ended_at_zero ~pos:initial_pos ~dir ~dist then 1 else 0 in

      if hw_pos <> sw_pos || hw_part1 <> sw_ended || hw_part2 <> sw_zeros then begin
        incr errors;
        if !errors <= 5 then
          Printf.printf "  ERROR: dir=%d dist=%d: hw=(%d,%d,%d) sw=(%d,%d,%d)\n"
            dir dist hw_pos hw_part1 hw_part2 sw_pos sw_ended sw_zeros
      end
    done
  done;

  if !errors = 0 then begin
    Printf.printf "  ✓ All 8192 tests passed!\n";
    true
  end else begin
    Printf.printf "  ✗ %d errors found\n" !errors;
    false
  end

(* Test combinational logic from ALL 100 starting positions *)
let test_exhaustive_all_positions () =
  Printf.printf "\nExhaustive Testing (ALL positions, combinational)\n";
  Printf.printf "-------------------------------------------------\n";
  Printf.printf "Testing 819,200 combinations: pos ∈ [0,99], dir ∈ {0,1}, dist ∈ [0,4095]\n";

  let errors = ref 0 in
  let tested = ref 0 in

  for pos = 0 to 99 do
    for dir = 0 to 1 do
      for dist = 0 to 4095 do
        let (hw_pos, hw_ended, hw_zeros) = test_comb_logic ~pos ~dir ~dist in

        let sw_pos = Day01.Spec.new_position ~pos ~dir ~dist in
        let sw_zeros = Day01.Spec.zeros ~pos ~dir ~dist in
        let sw_ended = if sw_pos = 0 then 1 else 0 in

        if hw_pos <> sw_pos || hw_ended <> sw_ended || hw_zeros <> sw_zeros then begin
          incr errors;
          if !errors <= 5 then
            Printf.printf "  ERROR: pos=%d dir=%d dist=%d: hw=(%d,%d,%d) sw=(%d,%d,%d)\n"
              pos dir dist hw_pos hw_ended hw_zeros sw_pos sw_ended sw_zeros
        end;
        incr tested
      done
    done
  done;

  if !errors = 0 then begin
    Printf.printf "  ✓ All %d tests passed!\n" !tested;
    true
  end else begin
    Printf.printf "  ✗ %d errors found in %d tests\n" !errors !tested;
    false
  end

let test_sequence () =
  Printf.printf "\nSequence Testing\n";
  Printf.printf "----------------\n";

  let sim = create_sim () in
  reset_sim sim;

  let test_cases = [
    (1, 50);   (* R50: 50 + 50 = 100 -> pos=0 *)
    (0, 25);   (* L25: 0 -> 75 *)
    (1, 125);  (* R125: 75 -> 0, crosses twice *)
    (1, 99);   (* R99: 0 -> 99 *)
    (0, 100);  (* L100: 99 -> 99, crosses once *)
  ] in

  let sw_pos = ref 50 in
  let sw_part1 = ref 0 in
  let sw_part2 = ref 0 in
  let errors = ref 0 in

  List.iter (fun (dir, dist) ->
    sw_part2 := !sw_part2 + Day01.Spec.zeros ~pos:!sw_pos ~dir ~dist;
    let new_pos = Day01.Spec.new_position ~pos:!sw_pos ~dir ~dist in
    if new_pos = 0 then incr sw_part1;
    sw_pos := new_pos;

    run_instruction sim ~dir ~dist;
    let (hw_pos, hw_part1, hw_part2) = read_outputs sim in

    if hw_pos <> !sw_pos || hw_part1 <> !sw_part1 || hw_part2 <> !sw_part2 then begin
      incr errors;
      Printf.printf "  ERROR after %s%d: hw=(%d,%d,%d) sw=(%d,%d,%d)\n"
        (if dir = 1 then "R" else "L") dist
        hw_pos hw_part1 hw_part2 !sw_pos !sw_part1 !sw_part2
    end else
      Printf.printf "  ✓ %s%d: pos=%d part1=%d part2=%d\n"
        (if dir = 1 then "R" else "L") dist hw_pos hw_part1 hw_part2
  ) test_cases;

  if !errors = 0 then begin
    Printf.printf "  ✓ Sequence test passed!\n";
    true
  end else begin
    Printf.printf "  ✗ %d errors\n" !errors;
    false
  end

let test_position_range () =
  Printf.printf "\nPosition Range Testing (all starting positions)\n";
  Printf.printf "------------------------------------------------\n";

  let errors = ref 0 in
  for pos = 0 to 99 do
    for dir = 0 to 1 do
      for dist = 0 to 4095 do
        let (hw_pos, _, _) = test_comb_logic ~pos ~dir ~dist in
        if hw_pos < 0 || hw_pos >= 100 then begin
          incr errors;
          if !errors <= 5 then
            Printf.printf "  ERROR: pos=%d dir=%d dist=%d -> invalid pos=%d\n" pos dir dist hw_pos
        end
      done
    done
  done;

  if !errors = 0 then begin
    Printf.printf "  ✓ Position always in [0,99] for all 819,200 combinations\n";
    true
  end else begin
    Printf.printf "  ✗ %d range errors\n" !errors;
    false
  end

(* ============================================================
   Main
   ============================================================ *)

let () =
  Printf.printf "Day 01: Simulation and Exhaustive Testing\n";
  Printf.printf "==========================================\n\n";

  let filename =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../../common/test_vectors/day01.txt"
  in

  let results = [
    simulate_test_vector filename;
    test_sequence ();
    test_position_range ();
    test_exhaustive_from_pos50 ();
    test_exhaustive_all_positions ();
  ] in

  Printf.printf "\n==========================================\n";
  if List.for_all Fun.id results then
    Printf.printf "✓ All tests passed!\n"
  else
    Printf.printf "✗ Some tests failed.\n"
