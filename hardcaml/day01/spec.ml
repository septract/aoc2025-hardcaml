(* Day 01: Software Specification

   This defines the CORRECT behavior in plain, readable OCaml.
   Both simulate.ml and verify.ml import this as the source of truth.
*)

(** Position after rotating the dial.
    - dir=1 (Right): add distance, wrap at 100
    - dir=0 (Left): subtract distance, wrap at 100 *)
let new_position ~pos ~dir ~dist =
  if dir = 1 then
    (pos + dist) mod 100
  else
    (pos + 100 - (dist mod 100)) mod 100

(** Count zero crossings for RIGHT rotation.
    Moving right from pos by dist crosses zero floor((pos + dist) / 100) times. *)
let zeros_right ~pos ~dist =
  (pos + dist) / 100

(** Count zero crossings for LEFT rotation.
    - If starting at 0: cross zero floor(dist / 100) times
    - If dist >= pos: we pass through zero, count = floor((dist - pos + 100) / 100)
    - If dist < pos: we don't reach zero, count = 0 *)
let zeros_left ~pos ~dist =
  if pos = 0 then
    dist / 100
  else if dist >= pos then
    (dist - pos + 100) / 100
  else
    0

(** Total zero crossings for one instruction *)
let zeros ~pos ~dir ~dist =
  if dir = 1 then zeros_right ~pos ~dist
  else zeros_left ~pos ~dist

(** Did we end at position 0? *)
let ended_at_zero ~pos ~dir ~dist =
  new_position ~pos ~dir ~dist = 0

(** Solve the full puzzle given a list of (dir, dist) instructions.
    Returns (part1_count, part2_count) *)
let solve instructions =
  let pos = ref 50 in
  let part1 = ref 0 in
  let part2 = ref 0 in

  List.iter (fun (dir, dist) ->
    part2 := !part2 + zeros ~pos:!pos ~dir ~dist;
    let new_pos = new_position ~pos:!pos ~dir ~dist in
    if new_pos = 0 then incr part1;
    pos := new_pos
  ) instructions;

  (!part1, !part2)

(* ============================================================
   Bit-accurate spec for SAT verification

   This mirrors the OCaml spec above but uses Comb.S operations.
   It shares div_100/mod_100 with solution.ml since those are
   proven correct by exhaustive testing.
   ============================================================ *)

module Make_comb (C : Hardcaml.Comb.S) = struct
  open C

  (* Import division primitives from solution - proven correct by testing *)
  module Arith = Solution.Dial.Make_comb(C)
  let div_100 = Arith.div_by_100
  let mod_100 = Arith.mod_100

  let pos_width = 7
  let dist_width = 12

  (** Position after rotating: mirrors OCaml new_position *)
  let new_position ~pos ~dir ~dist =
    let pos_ext = uresize pos dist_width in
    let hundred = of_int ~width:dist_width 100 in

    (* Right: (pos + dist) mod 100 *)
    let right_sum = uresize pos_ext 13 +: uresize dist 13 in
    let right_pos = mod_100 right_sum in

    (* Left: (pos + 100 - (dist mod 100)) mod 100 *)
    let dist_mod = mod_100 dist in
    let left_raw = pos_ext +: hundred -: dist_mod in
    let left_pos = mod_100 left_raw in

    uresize (mux2 dir right_pos left_pos) pos_width

  (** Zero crossings for RIGHT rotation: (pos + dist) / 100 *)
  let zeros_right ~pos ~dist =
    let sum = uresize pos 13 +: uresize dist 13 in
    div_100 sum

  (** Zero crossings for LEFT rotation: mirrors OCaml zeros_left *)
  let zeros_left ~pos ~dist =
    let pos_ext = uresize pos dist_width in
    let zero32 = of_int ~width:32 0 in

    let pos_is_zero = pos_ext ==: of_int ~width:dist_width 0 in
    let dist_ge_pos = dist >=: pos_ext in

    (* When pos = 0: zeros = dist / 100 *)
    let zeros_pos_zero = div_100 dist in

    (* When pos > 0 and dist >= pos: zeros = (dist - pos + 100) / 100 *)
    let diff = uresize dist 13 -: uresize pos_ext 13 +: of_int ~width:13 100 in
    let zeros_pos_nonzero = div_100 diff in

    mux2 pos_is_zero zeros_pos_zero
      (mux2 dist_ge_pos zeros_pos_nonzero zero32)

  (** Total zero crossings: mirrors OCaml zeros *)
  let zeros ~pos ~dir ~dist =
    mux2 dir (zeros_right ~pos ~dist) (zeros_left ~pos ~dist)
end
