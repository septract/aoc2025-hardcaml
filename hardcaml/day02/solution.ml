(* Day 02: Gift Shop - Hardware Implementation

   Hardware design for finding repeated-pattern numbers in ranges.

   Strategy: Generate all possible repeated-pattern numbers and check
   if they fall within the given range. This is efficient because:
   - There are only ~110,000 repeated patterns up to 10 digits
   - Ranges can span millions of numbers
   - Generation is O(patterns), not O(range_size)

   Hardware approach:
   - Pattern generator: sequences through all pattern values
   - Repetition builder: creates pattern repeated k times
   - Range checker: tests if value is in [lo, hi]
   - Accumulator: sums matching values

   Note: Hardware division is expensive, so we generate patterns
   rather than check arbitrary numbers for the "repeated" property.
*)

open Hardcaml

module Config = struct
  let value_width = 40      (* Support values up to ~1 trillion *)
  let sum_width = 64        (* Sum accumulator *)
  let max_digits = 10       (* Max digits in a number *)
  let max_pattern_len = 5   (* Max pattern length (for 10-digit total with 2 reps) *)
end

(* Powers of 10 as constants *)
let pow10 = [|
  1; 10; 100; 1000; 10000;
  100000; 1000000; 10000000; 100000000; 1000000000;
  10000000000;
|]

(* ============================================================
   Pattern Builder - Constructs repeated patterns

   Given a pattern value and repetition count, builds the
   repeated number. E.g., pattern=12, reps=3 -> 121212
   ============================================================ *)

module Pattern_builder = struct
  open Signal

  let width = Config.value_width

  (* Build a number by repeating pattern reps times.
     pattern_len is the number of digits in pattern (1-5).
     E.g., pattern=12, pattern_len=2, reps=3 -> 121212

     We compute: result = pattern * (10^(len*2) + 10^len + 1) for reps=3
     Or iteratively: start with pattern, then result = result * 10^len + pattern *)
  let build ~pattern ~pattern_len ~reps =
    (* multiplier = 10^pattern_len, selected by pattern_len *)
    let mult = mux pattern_len (Array.to_list (Array.map (of_int ~width) pow10)) in

    (* Unroll the iteration: result_i = result_{i-1} * mult + pattern
       Multiplication doubles width, so we truncate back to width after each step.
       This is safe because we know the max result fits in width bits. *)
    let max_reps = 10 in
    let pattern_wide = uresize pattern width in
    let results = Array.make (max_reps + 1) (of_int ~width 0) in

    (* Build up results iteratively *)
    results.(1) <- pattern_wide;
    for i = 2 to max_reps do
      (* result * mult produces 2*width bits, truncate to width *)
      let product = uresize (results.(i-1) *: mult) width in
      results.(i) <- product +: pattern_wide
    done;

    (* Select based on reps *)
    mux reps (Array.to_list results)
end

(* ============================================================
   Sequential Controller - Iterates through patterns

   State machine that:
   1. Iterates through pattern_len (1 to max_pattern_len)
   2. For each len, iterates through patterns (10^(len-1) to 10^len - 1)
   3. For each pattern, iterates through reps (2 to max for Part2)
   4. Builds the repeated value and checks against range
   5. Accumulates sum of matching values
   ============================================================ *)

module Range_checker = struct
  module I = struct
    type 'a t = {
      clock : 'a;
      clear : 'a;
      start : 'a;
      range_lo : 'a [@bits Config.value_width];
      range_hi : 'a [@bits Config.value_width];
      part2_mode : 'a;  (* 0=Part1 (reps=2 only), 1=Part2 (reps>=2) *)
    } [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = {
      done_ : 'a;
      sum : 'a [@bits Config.sum_width];
      busy : 'a;
    } [@@deriving hardcaml]
  end

  (* State encoding *)
  let st_idle = 0
  let st_gen = 1
  let st_done = 2

  let create (i : _ I.t) =
    let open Signal in
    let spec = Reg_spec.create ~clock:i.clock () in
    let width = Config.value_width in

    (* Registers - use wire for feedback *)
    let state = wire 2 in
    let pattern_len = wire 4 in      (* 1 to max_pattern_len *)
    let pattern = wire width in       (* Current pattern value *)
    let reps = wire 4 in              (* Current repetition count *)
    let sum = wire Config.sum_width in

    (* Compute current repeated value *)
    let current_value = Pattern_builder.build ~pattern ~pattern_len ~reps in

    (* Check if in range *)
    let in_range =
      (current_value >=: i.range_lo) &: (current_value <=: i.range_hi)
    in

    (* Compute limits for current pattern_len *)
    (* pattern_max = 10^len - 1 *)
    let pattern_max = mux pattern_len (
      of_int ~width 0 ::  (* index 0, unused *)
      Array.to_list (Array.init Config.max_pattern_len (fun i ->
        of_int ~width (pow10.(i + 1) - 1)  (* len=1: max=9, len=2: max=99, etc. *)
      ))
    ) in

    (* Max reps for current pattern_len such that total digits <= max_digits *)
    (* max_reps = max_digits / pattern_len *)
    let max_reps_for_len = mux pattern_len (
      of_int ~width:4 10 ::  (* index 0, unused *)
      Array.to_list (Array.init Config.max_pattern_len (fun i ->
        of_int ~width:4 (Config.max_digits / (i + 1))
      ))
    ) in

    (* State flags *)
    let is_idle = state ==: of_int ~width:2 st_idle in
    let is_gen = state ==: of_int ~width:2 st_gen in
    let is_done = state ==: of_int ~width:2 st_done in

    (* Iteration control *)
    let pattern_at_max = pattern >=: pattern_max in
    let len_at_max = pattern_len >=: of_int ~width:4 Config.max_pattern_len in
    let reps_at_max = reps >=: max_reps_for_len in

    (* In Part 1 mode, we only use reps=2, so reps is always "done" *)
    let reps_done = mux2 i.part2_mode reps_at_max vdd in

    (* Finished when: at max pattern, at max len, and reps done *)
    let all_done = pattern_at_max &: len_at_max &: reps_done in

    (* State transitions *)
    let next_state =
      mux2 i.clear (of_int ~width:2 st_idle)
        (mux2 (is_idle &: i.start) (of_int ~width:2 st_gen)
          (mux2 (is_gen &: all_done) (of_int ~width:2 st_done)
            (mux2 (is_done &: i.start) (of_int ~width:2 st_gen)
              state)))
    in

    (* Pattern iteration logic *)
    (* Order: for each len, for each pattern, for each reps (Part2 only) *)
    let advance_reps = ~:reps_done in
    let advance_pattern = reps_done &: ~:pattern_at_max in
    let advance_len = reps_done &: pattern_at_max &: ~:len_at_max in

    let next_reps =
      mux2 i.part2_mode
        (mux2 advance_reps (reps +:. 1)
          (mux2 (reps_done &: pattern_at_max) (of_int ~width:4 2)
            (mux2 reps_done (of_int ~width:4 2) reps)))
        (of_int ~width:4 2)  (* Part 1: always reps=2 *)
    in

    let next_pattern_len =
      mux2 advance_len (pattern_len +:. 1) pattern_len
    in

    (* When advancing pattern, reset to min for current (possibly new) len *)
    let next_pattern_min = mux (mux2 advance_len (pattern_len +:. 1) pattern_len) (
      of_int ~width 0 ::
      of_int ~width 1 ::
      Array.to_list (Array.init (Config.max_pattern_len - 1) (fun i ->
        of_int ~width pow10.(i + 1)
      ))
    ) in

    let next_pattern =
      mux2 (reps_done &: pattern_at_max) next_pattern_min
        (mux2 advance_pattern (pattern +:. 1) pattern)
    in

    (* Initial values *)
    let init_pattern = of_int ~width 1 in
    let init_len = of_int ~width:4 1 in
    let init_reps = of_int ~width:4 2 in

    (* Register updates *)
    state <== reg spec ~enable:vdd next_state;

    pattern <== reg spec ~enable:vdd
      (mux2 i.clear init_pattern
        (mux2 (is_idle &: i.start) init_pattern
          (mux2 is_gen next_pattern pattern)));

    pattern_len <== reg spec ~enable:vdd
      (mux2 i.clear init_len
        (mux2 (is_idle &: i.start) init_len
          (mux2 is_gen next_pattern_len pattern_len)));

    reps <== reg spec ~enable:vdd
      (mux2 i.clear init_reps
        (mux2 (is_idle &: i.start) init_reps
          (mux2 is_gen next_reps reps)));

    (* Sum accumulation - add current_value if in range and generating *)
    let add_to_sum = is_gen &: in_range in
    sum <== reg spec ~enable:vdd
      (mux2 i.clear (of_int ~width:Config.sum_width 0)
        (mux2 (is_idle &: i.start) (of_int ~width:Config.sum_width 0)
          (mux2 add_to_sum
            (sum +: uresize current_value Config.sum_width)
            sum)));

    { O.done_ = is_done; sum; busy = is_gen }
end

(* Module aliases for top-level access *)
module I = Range_checker.I
module O = Range_checker.O
let create = Range_checker.create
