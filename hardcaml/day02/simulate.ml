(* Day 02: Gift Shop - Simulation and Testing *)

open Day02.Spec
open Hardcaml
open Day02.Solution

let example_input =
  "11-22,95-115,998-1012,1188511880-1188511890,222220-222224," ^
  "1698522-1698528,446443-446449,38593856-38593862,565653-565659," ^
  "824824821-824824827,2121212118-2121212124"

let () =
  Printf.printf "Day 02: Gift Shop\n";
  Printf.printf "=================\n\n";

  (* Test individual is_invalid functions *)
  Printf.printf "Testing is_invalid_part1:\n";
  let test_cases_p1 = [
    (11, true); (22, true); (55, true);
    (99, true); (6464, true); (123123, true);
    (101, false); (1010, true); (1188511885, true);
    (222222, true); (446446, true); (38593859, true);
  ] in
  List.iter (fun (n, expected) ->
    let result = is_invalid_part1 n in
    let status = if result = expected then "OK" else "FAIL" in
    Printf.printf "  is_invalid_part1(%d) = %b [%s]\n" n result status
  ) test_cases_p1;

  Printf.printf "\nTesting is_invalid_part2:\n";
  let test_cases_p2 = [
    (11, true); (22, true); (55, true);
    (99, true); (111, true); (999, true);
    (1010, true); (6464, true); (123123, true);
    (1111, true); (121212, true); (1212121212, true);
    (1111111, true); (123123123, true);
    (565656, true); (824824824, true); (2121212121, true);
    (101, false); (12345, false);
  ] in
  List.iter (fun (n, expected) ->
    let result = is_invalid_part2 n in
    let status = if result = expected then "OK" else "FAIL" in
    Printf.printf "  is_invalid_part2(%d) = %b [%s]\n" n result status
  ) test_cases_p2;

  (* Test example *)
  Printf.printf "\n--- Example Input ---\n";
  let example_ranges = parse_ranges example_input in
  Printf.printf "Parsed %d ranges\n" (List.length example_ranges);

  let part1_example = solve_part1 example_ranges in
  Printf.printf "Part 1 (example): %d (expected 1227775554)\n" part1_example;

  let part2_example = solve_part2 example_ranges in
  Printf.printf "Part 2 (example): %d (expected 4174379265)\n" part2_example;

  (* Test with actual input *)
  let filename =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../../common/test_vectors/day02.txt"
  in

  Printf.printf "\n--- Puzzle Input ---\n";
  Printf.printf "Reading: %s\n" filename;

  let ic = open_in filename in
  let input = input_line ic in
  close_in ic;

  let ranges = parse_ranges input in
  Printf.printf "Parsed %d ranges\n" (List.length ranges);

  let part1 = solve_part1 ranges in
  Printf.printf "Part 1: %d\n" part1;

  let part2 = solve_part2 ranges in
  Printf.printf "Part 2: %d\n" part2;

  (* Verify example results *)
  Printf.printf "\n--- Verification ---\n";
  if part1_example = 1227775554 then
    Printf.printf "Part 1 example: PASS\n"
  else
    Printf.printf "Part 1 example: FAIL (got %d, expected 1227775554)\n" part1_example;

  if part2_example = 4174379265 then
    Printf.printf "Part 2 example: PASS\n"
  else
    Printf.printf "Part 2 example: FAIL (got %d, expected 4174379265)\n" part2_example;

  (* Hardware simulation *)
  Printf.printf "\n--- Hardware Simulation ---\n";

  let module Sim = Cyclesim.With_interface(I)(O) in
  let sim = Sim.create create in

  let test_hw_range ~lo ~hi ~part2_mode =
    let inp = Cyclesim.inputs sim in
    let out = Cyclesim.outputs sim in

    (* Reset *)
    inp.clear := Bits.of_int ~width:1 1;
    inp.start := Bits.of_int ~width:1 0;
    inp.range_lo := Bits.of_int ~width:Config.value_width lo;
    inp.range_hi := Bits.of_int ~width:Config.value_width hi;
    inp.part2_mode := Bits.of_int ~width:1 (if part2_mode then 1 else 0);
    Cyclesim.cycle sim;
    inp.clear := Bits.of_int ~width:1 0;
    Cyclesim.cycle sim;

    (* Start *)
    inp.start := Bits.of_int ~width:1 1;
    Cyclesim.cycle sim;
    inp.start := Bits.of_int ~width:1 0;

    (* Run until done (with timeout) *)
    let max_cycles = 1000000 in
    let cycles = ref 0 in
    while Bits.to_int !(out.done_) = 0 && !cycles < max_cycles do
      Cyclesim.cycle sim;
      incr cycles
    done;

    if !cycles >= max_cycles then begin
      Printf.printf "  TIMEOUT after %d cycles\n" max_cycles;
      -1
    end else begin
      let sum = Bits.to_int !(out.sum) in
      Printf.printf "  Range %d-%d (part%d): sum=%d (%d cycles)\n"
        lo hi (if part2_mode then 2 else 1) sum !cycles;
      sum
    end
  in

  (* Test a few small ranges and compare with software *)
  Printf.printf "Testing small ranges (HW vs SW comparison):\n";

  let test_ranges = [
    (11, 22);       (* expect 11+22=33 for part1, same for part2 *)
    (95, 115);      (* expect 99 for part1, 99+111=210 for part2 *)
    (998, 1012);    (* expect 1010 for part1, 999+1010 for part2 *)
    (1, 100);       (* all 2-digit repeated: 11,22,...,99 = 495 *)
    (100, 1000);    (* 111,222,...,999 for part2 *)
  ] in

  let errors = ref 0 in

  List.iter (fun (lo, hi) ->
    (* Part 1 *)
    let sw_p1 = sum_invalid_in_range ~invalid_list:(all_invalid_part1 ~max_digits:10) ~lo ~hi in
    let hw_p1 = test_hw_range ~lo ~hi ~part2_mode:false in
    if sw_p1 <> hw_p1 then begin
      Printf.printf "    MISMATCH Part1: SW=%d HW=%d\n" sw_p1 hw_p1;
      incr errors
    end else
      Printf.printf "    Part1 match: %d\n" sw_p1;

    (* Part 2 *)
    let sw_p2 = sum_invalid_in_range ~invalid_list:(all_invalid_part2 ~max_digits:10) ~lo ~hi in
    let hw_p2 = test_hw_range ~lo ~hi ~part2_mode:true in
    if sw_p2 <> hw_p2 then begin
      Printf.printf "    MISMATCH Part2: SW=%d HW=%d\n" sw_p2 hw_p2;
      incr errors
    end else
      Printf.printf "    Part2 match: %d\n" sw_p2;
  ) test_ranges;

  Printf.printf "\n--- Hardware Test Summary ---\n";
  if !errors = 0 then
    Printf.printf "All hardware tests PASSED!\n"
  else
    Printf.printf "%d hardware tests FAILED!\n" !errors
