(* Day 01: Simulation runner for hardware implementation *)

open Hardcaml
open Day01.Solution

(* Parse instruction like "L50" or "R123" *)
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

(* Read all instructions from file *)
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

(* Hardware simulation using Hardcaml's simulation framework *)
module Sim = Cyclesim.With_interface(Dial.I)(Dial.O)

let simulate_hardware instructions =
  let sim = Sim.create Dial.create in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  (* Helper to set inputs *)
  let set_inputs ~clear ~valid ~dir ~dist =
    inputs.clear := Bits.of_int ~width:1 (if clear then 1 else 0);
    inputs.valid := Bits.of_int ~width:1 (if valid then 1 else 0);
    inputs.dir := Bits.of_int ~width:1 dir;
    inputs.dist := Bits.of_int ~width:Dial.dist_width dist
  in

  (* Reset *)
  set_inputs ~clear:true ~valid:false ~dir:0 ~dist:0;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;

  set_inputs ~clear:false ~valid:false ~dir:0 ~dist:0;
  Cyclesim.cycle sim;

  (* Process instructions *)
  List.iter (fun (dir, dist) ->
    set_inputs ~clear:false ~valid:true ~dir ~dist;
    Cyclesim.cycle sim;
  ) instructions;

  set_inputs ~clear:false ~valid:false ~dir:0 ~dist:0;
  Cyclesim.cycle sim;

  let part1 = Bits.to_int !(outputs.part1_count) in
  let part2 = Bits.to_int !(outputs.part2_count) in
  let final_pos = Bits.to_int !(outputs.position) in
  (part1, part2, final_pos)

let () =
  let filename =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../../common/test_vectors/day01.txt"
  in

  Printf.printf "Day 01: Safe Dial (Hardware Implementation)\n";
  Printf.printf "============================================\n\n";

  Printf.printf "Reading: %s\n" filename;
  let instructions = read_instructions filename in
  Printf.printf "Loaded %d instructions\n\n" (List.length instructions);

  Printf.printf "Software Reference (from spec.ml):\n";
  let (sw_part1, sw_part2) = Day01.Spec.solve instructions in
  Printf.printf "  Part 1: %d\n" sw_part1;
  Printf.printf "  Part 2: %d\n\n" sw_part2;

  Printf.printf "Hardware Simulation:\n";
  let (hw_part1, hw_part2, hw_pos) = simulate_hardware instructions in
  Printf.printf "  Part 1: %d\n" hw_part1;
  Printf.printf "  Part 2: %d\n" hw_part2;
  Printf.printf "  Final position: %d\n\n" hw_pos;

  if sw_part1 = hw_part1 && sw_part2 = hw_part2 then
    Printf.printf "✓ Hardware matches software!\n"
  else
    Printf.printf "✗ MISMATCH detected.\n"
