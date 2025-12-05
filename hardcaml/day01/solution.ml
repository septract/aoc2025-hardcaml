(* Day 01: Safe Dial - Hardcaml Solution with Hardware Division

   Division by 100 implemented using multiplication by reciprocal:
   x / 100 ≈ (x * 1311) >> 17  (accurate for x up to ~5000)
   1311/131072 = 0.01000213, slightly > 1/100, so floor() is correct
*)

open Hardcaml

module Dial = struct
  let pos_width = 7       (* 0-99 *)
  let dist_width = 12     (* Support distances up to 4095 *)
  let count_width = 16
  let mult_width = 32     (* For multiplication intermediate results *)

  module I = struct
    type 'a t = {
      clock : 'a;
      clear : 'a;
      valid : 'a;
      dir : 'a [@bits 1];
      dist : 'a [@bits dist_width];
    } [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = {
      position : 'a [@bits pos_width];
      part1_count : 'a [@bits count_width];
      part2_count : 'a [@bits count_width];
      ready : 'a;
    } [@@deriving hardcaml]
  end

  (* Hardware division by 100 using multiplication by reciprocal
     x / 100 ≈ (x * 1311) >> 17
     1311/131072 = 0.01000213, slightly > 1/100, ensures correct floor() *)
  let div_by_100 x =
    let open Signal in
    let x_wide = uresize x mult_width in
    let multiplier = of_int ~width:mult_width 1311 in
    let product = x_wide *: multiplier in
    (* Shift right by 17 *)
    srl product 17

  (* Hardware modulo 100: x mod 100 = x - 100 * (x / 100) *)
  let mod_100 x =
    let open Signal in
    let x_wide = uresize x mult_width in
    let quotient = uresize (div_by_100 x) mult_width in
    let hundred = of_int ~width:mult_width 100 in
    let product = uresize (quotient *: hundred) mult_width in
    let remainder = x_wide -: product in
    uresize remainder dist_width

  let calc_new_position ~pos ~dir ~dist =
    let open Signal in
    let pos_ext = uresize pos dist_width in
    let hundred = of_int ~width:dist_width 100 in

    (* Right: (pos + dist) mod 100 *)
    let right_sum = pos_ext +: dist in
    let right_pos = mod_100 right_sum in

    (* Left: (pos + 100 - (dist mod 100)) mod 100 *)
    let dist_mod = mod_100 dist in
    let left_raw = pos_ext +: hundred -: dist_mod in
    let left_pos = mod_100 left_raw in

    uresize (mux2 dir right_pos left_pos) pos_width

  (* Count zeros for RIGHT rotation: (pos + dist) / 100 *)
  let count_zeros_right ~pos ~dist =
    let open Signal in
    let pos_ext = uresize pos dist_width in
    let sum = pos_ext +: dist in
    uresize (div_by_100 sum) mult_width

  (* Count zeros for LEFT rotation *)
  let count_zeros_left ~pos ~dist =
    let open Signal in
    let pos_ext = uresize pos dist_width in
    let hundred = of_int ~width:dist_width 100 in
    let zero = of_int ~width:mult_width 0 in

    let pos_is_zero = pos_ext ==: (of_int ~width:dist_width 0) in
    let dist_ge_pos = dist >=: pos_ext in

    (* When pos = 0: zeros = dist / 100 *)
    let zeros_pos_zero = uresize (div_by_100 dist) mult_width in

    (* When pos > 0 and dist >= pos: zeros = (dist - pos + 100) / 100 *)
    let diff = dist -: pos_ext +: hundred in
    let zeros_pos_nonzero = uresize (div_by_100 diff) mult_width in

    mux2 pos_is_zero
      zeros_pos_zero
      (mux2 dist_ge_pos zeros_pos_nonzero zero)

  let process_instruction ~pos ~dir ~dist =
    let open Signal in
    let new_pos = calc_new_position ~pos ~dir ~dist in

    (* Part 1: ended at 0? *)
    let ended_at_zero = new_pos ==: (of_int ~width:pos_width 0) in
    let part1_inc = uresize (mux2 ended_at_zero
      (of_int ~width:1 1)
      (of_int ~width:1 0)) count_width in

    (* Part 2: all zero crossings *)
    let zeros_right = count_zeros_right ~pos ~dist in
    let zeros_left = count_zeros_left ~pos ~dist in
    let part2_inc = uresize (mux2 dir zeros_right zeros_left) count_width in

    (new_pos, part1_inc, part2_inc)

  let create (i : _ I.t) =
    let open Signal in
    (* Don't use clear in Reg_spec - we'll handle reset values manually *)
    let spec = Reg_spec.create ~clock:i.clock () in
    let initial_pos = of_int ~width:pos_width 50 in

    (* Position register - resets to 50 *)
    let pos = reg_fb ~width:pos_width ~f:(fun pos ->
      mux2 i.clear initial_pos
        (mux2 i.valid
          (let new_pos, _, _ = process_instruction ~pos ~dir:i.dir ~dist:i.dist in new_pos)
          pos)
    ) spec in

    (* Part 1 counter - resets to 0 *)
    let part1 = reg_fb ~width:count_width ~f:(fun cnt ->
      mux2 i.clear (of_int ~width:count_width 0)
        (mux2 i.valid
          (let _, inc, _ = process_instruction ~pos ~dir:i.dir ~dist:i.dist in cnt +: inc)
          cnt)
    ) spec in

    (* Part 2 counter - resets to 0 *)
    let part2 = reg_fb ~width:count_width ~f:(fun cnt ->
      mux2 i.clear (of_int ~width:count_width 0)
        (mux2 i.valid
          (let _, _, inc = process_instruction ~pos ~dir:i.dir ~dist:i.dist in cnt +: inc)
          cnt)
    ) spec in

    { O.position = pos; part1_count = part1; part2_count = part2;
      ready = of_int ~width:1 1 }
end

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

(* Software reference for verification *)
let solve_software instructions =
  let pos = ref 50 in
  let part1 = ref 0 in
  let part2 = ref 0 in

  List.iter (fun (dir, dist) ->
    let p = !pos in
    let zeros =
      if dir = 1 then (p + dist) / 100
      else if p = 0 then dist / 100
      else if dist >= p then (dist - p + 100) / 100
      else 0
    in
    part2 := !part2 + zeros;

    let new_pos =
      if dir = 1 then (p + dist) mod 100
      else (p + 100 - (dist mod 100)) mod 100
    in
    pos := new_pos;
    if new_pos = 0 then part1 := !part1 + 1
  ) instructions;

  (!part1, !part2)

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

  Printf.printf "Software Reference:\n";
  let (sw_part1, sw_part2) = solve_software instructions in
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
