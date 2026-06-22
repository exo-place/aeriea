# Text Sandbox UI — re-verification (facts only)

Scope: `scripts/text_sandbox.gd`, `scenes/text_sandbox.tscn`, `scripts/body/face/*`,
`scripts/sim/*` (via `scripts/text/maren_history.gd`). VERIFY ONLY.

## 1. Yellow text + white text after every response — CONFIRMED

After each fired verb, `_fire()` appends several colored lines via `_append_line(bbcode, color)`,
where the color arg is a Godot `Color` pushed with `push_color()` (`text_sandbox.gd:304-308`).

The two lines the user is asking about (per turn, in order):

- **Yellow-ish line** = the **memory callback / dialogue** line, colored
  `Color(0.85, 0.8, 0.7)` (warm tan/yellow) at `text_sandbox.gd:277` (and the same color
  for the on-return callback at `:197`). Its text is `_history.memory_callback()` — a
  remembered-slight / "you keep saying that" / kept-gift dialogue line surfaced from
  accumulated memory. It is **intended in-fiction content**, not debug — but only renders
  when `memory_callback() != ""`.

- **The dim cyan/teal line** = the **FACE READOUT (debug affect dump)**, colored
  `Color(0.5, 0.62, 0.6)` at `text_sandbox.gd:279` (and `:199` on return). Its text comes
  from `_face_read()` (`:290-294`):
  `"(face: valence %+.2f, tension %.2f, attention %.2f, arousal %.2f%s)"`.
  This is a **raw numeric ExprState dump** (valence/tension/attention/arousal + optional
  `emphasis=`), formatted in italics. It is **debug/affect-readout output**, not prose a
  player should see — it literally prints the ExprState floats that the face rig *would*
  render.

Other per-turn lines for reference (so the colors are unambiguous):
- `> <verb>` echo — `Color(0.85, 0.9, 0.95)` near-white (`:234`).
- outcome prose — `Color(0.9, 0.88, 0.82)` warm near-white (`:272`).
- `_describe(after)` scene/state prose — `Color(0.78, 0.82, 0.88)` pale blue-white (`:278`).

So "white text" the user sees = the outcome/description prose (`:272`, `:278`); the
"yellow text" = either the memory-callback dialogue (`:277`, warm tan) and/or, if they
mean the dim line, the face-readout debug dump (`:279`). The face readout is the
clear debug-output-shown-to-player candidate.

## 2. Face preview hookup — CONFIRMED NOT HOOKED UP

(a) **No 3D face/expression preview exists in the text sandbox scene.**
`scenes/text_sandbox.tscn` contains exactly one node: a `Control` running
`text_sandbox.gd`. No `BodyRig`, no `FaceRig`, no 3D nodes at all. `_ready()`
(`text_sandbox.gd:80-124`) builds only `VBoxContainer` + `Label` + `RichTextLabel` +
`HBoxContainer` + `LineEdit`.

(b) **The NPC's affect/mood does NOT drive a visible FaceRig in this scene — it is only
printed as text.** `text_sandbox.gd` never references `FaceRig`/`face_rig` and never calls
`apply_expression`. The only ExprState consumer in the text path is `_face_read()`
(`:290-294`), which calls `_history.current_expr()` (`maren_history.gd:92`) and then
*string-formats the floats* into the transcript. The ExprState→FaceRig signal/data path
that exists in the demo is absent here; the ExprState terminates in a `%`-format string.

(c) **The FaceRig expression system itself works (apply_expression is real and wired —
just not in this scene).**
- `FaceRig.apply_expression(e: ExprState)` is implemented at `face_rig.gd:170-173`
  (sets `_affect.target = e`); `step(delta)` composites gestures and `_drive_head()`
  (`face_rig.gd:192-198`); `_process` calls `step` (`:183-186`).
- It is exercised in the demo `scripts/body/face/face_demo.gd` (builds a BodyRig +
  FaceRig, `apply_expression` + `step` at `:85,:96,:113`; scene `scenes/face_demo.tscn`)
  and in `tests/face_expression_test.gd` (`apply_expression` at `:54,:105,:183`; emits a
  `=== RESULTS ===` line at `:31`).

Conclusion: a working expression rig EXISTS (demo + test), but the **text sandbox does not
instantiate or drive it**. The face state is text-only in this scene.

## 3. Input method — CONFIRMED (numbered menu via LineEdit)

- Input is a single `LineEdit` (`text_sandbox.gd:112-117`), placeholder
  "Type the number (or name) of an action and press Enter…" (`:113`), submitting on
  `text_submitted` → `_on_text_submitted` → `_submit` (`:116, :213-214`).
- Each turn `_present_menu()` prints a numbered list `"  N) <prompt>"` (`:179-181`) plus a
  literal `wait` option (`:182`).
- `_resolve_choice()` (`:240-250`): if the line `is_valid_int()`, it is treated as a
  **1-based menu index** (`idx = to_int() - 1`, bounds-checked against `_menu`); otherwise
  it matches the lowercased line against a verb name. `wait`/`leave` is special-cased in
  `_submit` (`:225-228`).

So: type-a-number (or verb name) into a LineEdit and press Enter. Confirmed.
