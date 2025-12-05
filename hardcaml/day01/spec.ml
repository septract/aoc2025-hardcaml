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
