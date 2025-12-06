(* Day 02: Gift Shop - Software Specification

   Invalid IDs are numbers made of repeated digit sequences:
   - Part 1: exactly 2 repetitions (e.g., 55, 6464, 123123)
   - Part 2: at least 2 repetitions (e.g., 111, 1212, 123123123)

   Key insight: Instead of checking every number in a range (could be millions),
   generate all possible repeated-pattern numbers and check if they're in range.
*)

(* Power of 10 *)
let pow10 n =
  let rec loop acc = function
    | 0 -> acc
    | n -> loop (acc * 10) (n - 1)
  in
  loop 1 n

(* Count digits in a number *)
let num_digits n =
  if n = 0 then 1
  else
    let rec count acc n =
      if n = 0 then acc
      else count (acc + 1) (n / 10)
    in
    count 0 n

(* Generate a number that is pattern repeated reps times.
   E.g., pattern=123, reps=2 -> 123123 *)
let make_repeated pattern reps =
  let pattern_len = num_digits pattern in
  let multiplier = pow10 pattern_len in
  let rec build acc = function
    | 0 -> acc
    | n -> build (acc * multiplier + pattern) (n - 1)
  in
  build 0 reps

(* Generate all numbers that are some pattern repeated exactly reps times,
   where the pattern has pattern_len digits.
   E.g., pattern_len=2, reps=2 -> 1010, 1111, 1212, ..., 9999 *)
let generate_repeated ~pattern_len ~reps =
  let min_pattern = if pattern_len = 1 then 1 else pow10 (pattern_len - 1) in
  let max_pattern = pow10 pattern_len - 1 in
  let result = ref [] in
  for p = min_pattern to max_pattern do
    result := make_repeated p reps :: !result
  done;
  List.rev !result

(* All invalid IDs for Part 1: exactly 2 repetitions, up to max_digits total *)
let all_invalid_part1 ~max_digits =
  let result = ref [] in
  for pattern_len = 1 to max_digits / 2 do
    result := generate_repeated ~pattern_len ~reps:2 @ !result
  done;
  List.sort_uniq compare !result

(* All invalid IDs for Part 2: at least 2 repetitions, up to max_digits total *)
let all_invalid_part2 ~max_digits =
  let seen = Hashtbl.create 10000 in
  for total_digits = 2 to max_digits do
    (* For each number of repetitions that divides total_digits *)
    for reps = 2 to total_digits do
      if total_digits mod reps = 0 then begin
        let pattern_len = total_digits / reps in
        List.iter (fun n -> Hashtbl.replace seen n ())
          (generate_repeated ~pattern_len ~reps)
      end
    done
  done;
  let result = Hashtbl.fold (fun k () acc -> k :: acc) seen [] in
  List.sort compare result

(* Sum invalid IDs in a single range *)
let sum_invalid_in_range ~invalid_list ~lo ~hi =
  List.fold_left (fun acc n ->
    if n >= lo && n <= hi then acc + n else acc
  ) 0 invalid_list

(* Parse input: "lo1-hi1,lo2-hi2,..." *)
let parse_ranges input =
  let input = String.trim input in
  let ranges = String.split_on_char ',' input in
  List.filter_map (fun s ->
    let s = String.trim s in
    if s = "" then None
    else
      match String.split_on_char '-' s with
      | [lo; hi] -> Some (int_of_string lo, int_of_string hi)
      | _ -> None
  ) ranges

(* Solve Part 1 *)
let solve_part1 ranges =
  (* Determine max digits needed from ranges *)
  let max_val = List.fold_left (fun acc (_, hi) -> max acc hi) 0 ranges in
  let max_digits = num_digits max_val in
  let invalid_list = all_invalid_part1 ~max_digits in
  List.fold_left (fun acc (lo, hi) ->
    acc + sum_invalid_in_range ~invalid_list ~lo ~hi
  ) 0 ranges

(* Solve Part 2 *)
let solve_part2 ranges =
  let max_val = List.fold_left (fun acc (_, hi) -> max acc hi) 0 ranges in
  let max_digits = num_digits max_val in
  let invalid_list = all_invalid_part2 ~max_digits in
  List.fold_left (fun acc (lo, hi) ->
    acc + sum_invalid_in_range ~invalid_list ~lo ~hi
  ) 0 ranges

(* Check if a number is invalid (Part 1) - for testing *)
let is_invalid_part1 n =
  let d = num_digits n in
  if d mod 2 <> 0 then false
  else
    let half = d / 2 in
    let divisor = pow10 half in
    let left = n / divisor in
    let right = n mod divisor in
    (* Also ensure no leading zeros in right half *)
    left = right && right >= pow10 (half - 1)

(* Check if a number is invalid (Part 2) - for testing *)
let is_invalid_part2 n =
  let d = num_digits n in
  let rec check_reps reps =
    if reps > d then false
    else if d mod reps <> 0 then check_reps (reps + 1)
    else
      let pattern_len = d / reps in
      let divisor = pow10 pattern_len in
      let pattern = n mod divisor in
      (* Check pattern has correct length (no leading zeros except for 0) *)
      if pattern_len > 1 && pattern < pow10 (pattern_len - 1) then
        check_reps (reps + 1)
      else
        let rec verify remaining count =
          if count = 0 then true
          else
            let segment = remaining mod divisor in
            if segment <> pattern then false
            else verify (remaining / divisor) (count - 1)
        in
        if verify n reps then true
        else check_reps (reps + 1)
  in
  check_reps 2
