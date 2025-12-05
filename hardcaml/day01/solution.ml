(* Day 01: Safe Dial - Hardcaml Solution with Hardware Division

   Division by 100 implemented using multiplication by reciprocal:
   x / 100 ≈ (x * 1311) >> 17  (accurate for x up to ~5000)
   1311/131072 = 0.01000213, slightly > 1/100, so floor() is correct

   The combinational logic is parameterized over Comb.S so it can be:
   - Instantiated with Signal for synthesis/simulation
   - Instantiated with Comb_gates for SAT verification
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

  (* ============================================================
     Combinational Logic - Parameterized over Comb.S
     This is the core logic that gets verified by SAT.
     ============================================================ *)

  module Make_comb (C : Comb.S) = struct
    open C

    (* Hardware division by 100 using multiplication by reciprocal
       x / 100 ≈ (x * 1311) >> 17
       1311/131072 = 0.01000213, slightly > 1/100, ensures correct floor() *)
    let div_by_100 x =
      let x_wide = uresize x mult_width in
      let multiplier = of_int ~width:mult_width 1311 in
      let product = x_wide *: multiplier in
      srl product 17

    (* Hardware modulo 100: x mod 100 = x - 100 * (x / 100) *)
    let mod_100 x =
      let x_wide = uresize x mult_width in
      let quotient = uresize (div_by_100 x) mult_width in
      let hundred = of_int ~width:mult_width 100 in
      let product = uresize (quotient *: hundred) mult_width in
      let remainder = x_wide -: product in
      uresize remainder dist_width

    let calc_new_position ~pos ~dir ~dist =
      let pos_ext = uresize pos dist_width in
      let hundred = of_int ~width:dist_width 100 in

      (* Right: (pos + dist) mod 100 *)
      (* Use 13 bits to avoid overflow: max value is 99 + 4095 = 4194 *)
      let right_sum = uresize pos_ext 13 +: uresize dist 13 in
      let right_pos = mod_100 right_sum in

      (* Left: (pos + 100 - (dist mod 100)) mod 100 *)
      let dist_mod = mod_100 dist in
      let left_raw = pos_ext +: hundred -: dist_mod in
      let left_pos = mod_100 left_raw in

      uresize (mux2 dir right_pos left_pos) pos_width

    (* Count zeros for RIGHT rotation: (pos + dist) / 100 *)
    let count_zeros_right ~pos ~dist =
      (* Use 13 bits to avoid overflow: max value is 99 + 4095 = 4194 *)
      let sum = uresize pos 13 +: uresize dist 13 in
      uresize (div_by_100 sum) mult_width

    (* Count zeros for LEFT rotation *)
    let count_zeros_left ~pos ~dist =
      let pos_ext = uresize pos dist_width in
      let zero = of_int ~width:mult_width 0 in

      let pos_is_zero = pos_ext ==: (of_int ~width:dist_width 0) in
      let dist_ge_pos = dist >=: pos_ext in

      (* When pos = 0: zeros = dist / 100 *)
      let zeros_pos_zero = uresize (div_by_100 dist) mult_width in

      (* When pos > 0 and dist >= pos: zeros = (dist - pos + 100) / 100 *)
      (* Use 13 bits to avoid overflow: max value is 4095 - 0 + 100 = 4195 *)
      let diff = uresize dist 13 -: uresize pos_ext 13 +: of_int ~width:13 100 in
      let zeros_pos_nonzero = uresize (div_by_100 diff) mult_width in

      mux2 pos_is_zero
        zeros_pos_zero
        (mux2 dist_ge_pos zeros_pos_nonzero zero)

    let process_instruction ~pos ~dir ~dist =
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
  end

  (* ============================================================
     Signal Instance - Used for synthesis and simulation
     ============================================================ *)

  module Comb = Make_comb(Signal)

  (* ============================================================
     Sequential Logic - Uses Signal-specific register features
     ============================================================ *)

  let create (i : _ I.t) =
    let open Signal in
    let open Comb in
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
