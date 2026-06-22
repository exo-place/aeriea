# Diagnosis — movement / parkour player + animation

Scope: `scripts/movement/interpreted_player.gd`, `scenes/test_level.tscn`,
`scripts/body/body_rig.gd` (procedural locomotion / motion-matching / foot-IK /
arm-IK), `scripts/body/clip_db.gd` (BDCC2 clip layer), `scripts/launcher.gd`.

Method: code read + headless inspection of the live `test_level.tscn` under xvfb
(bone-global positions, MM/clip frame resolution) + rendered screenshots (first-
person + two third-person angles). Renders saved next to this file:
`fp_view.png`, `tp_front.png`, `tp_walkdir.png`.

---

## VERDICT SUMMARY

| Reported symptom | Verdict | Evidence locus |
|---|---|---|
| FP camera embedded in own head mesh | **CONFIRMED** | render `fp_view.png`; camera world (0,1.545,20.0) inside skull; `interpreted_player.gd:256-261` |
| Character faces backward in parkour | **CONFIRMED** | renders `tp_front.png`/`tp_walkdir.png`; eyes at z=+0.1245 vs walk dir −Z; `interpreted_player.gd:188-192` |
| Animations snap to neutral / broken | **REFUTED** (locomotion+clips drive bones) — but pose magnitude weak | MM idle→frame 4646, run→frame 158; wave clip eases to w=0.64 |
| Can't switch away from parkour tab | **REFUTED as a hard trap** (Escape→bar works); real friction is soft | `launcher.gd:117-123`; simulated round-trip succeeds |
| Idle / breathing | **WORKING** | `_idle_micro` + `apply_micro_life` run; MM idle frame resolves |

---

## FINDING 1 — First-person camera is buried inside the head mesh  **[fix]**

The camera is a child of `CameraPivot`, which is positioned only on Y; there is
**no Z offset toward the face**, so the camera sits at the geometric centre of the
head, surrounded by skull/scalp/shoulder geometry.

Evidence:
- `interpreted_player.gd:160-167` builds `CameraPivot` + `Camera3D`; only
  `position.y` is ever set on the pivot.
- `_apply_body_eye_height()` (`interpreted_player.gd:246-269`) sets
  `_camera_pivot.position.y` and `_camera.near = 0.1` **and nothing on Z**. The
  docstring at `:241` *claims* "a small forward nudge toward the face front, −Z"
  but **no such nudge is implemented** — the code only touches `.y` and `.near`.
- Live measurement: camera world = `(0.0, 1.545, 20.0)`; head bone y=1.514,
  eye bones y=1.545, head_top=1.675. The camera Y is dead-centre of the skull and
  its Z equals the body origin (z=20.0) while the eyes are at z=20.138 (in front).
  `near=0.1` cannot clear the surrounding mesh.
- Render `fp_view.png`: the left ~40% of the frame is a solid dark mass — the
  player's own head/shoulder geometry rendered into the view.

What good requires: seat the camera at the actual eye landmark in **all three
axes** (use `eye.L`/`eye.R` global pose → world eye point, place the camera there
with a small forward bias along the body's facing axis), OR exclude the body mesh
from the FP camera's cull layer (render-layer mask), OR both. A near-plane bump
alone is insufficient. (The eye-height Y derivation at `:249-255` is sound; the
gap is the missing horizontal seat + the mesh not being culled in FP.)

## FINDING 2 — Body faces backward (face = +Z, movement/look = −Z)  **[fix]**

The MakeHuman rig's face points **+Z** (eye bones at z=+0.1245,
`base_body_rig.json`). The body is parented under the player with a Y-offset and
**no rotation** (`interpreted_player.gd:191-192`), and the comment at `:186`
asserts "The body faces −Z (Godot forward)" — which is **false for this rig**.
The player walks/looks along `−transform.basis.z` (`:407`) and yaw is applied as
`rotation.y = _yaw` (`:342`). Net: the face is on the opposite side from travel.

Evidence:
- Bone data: `eye.L/eye.R head z = +0.124535`, `head z = +0.016`, toes forward at
  z=+0.16 — anatomical front is +Z.
- Live: at spawn rotation.y=0, eye.L world z=20.138 (in **front**, +Z), camera
  looks toward −Z (z<20). The face is behind the look vector.
- Render `tp_walkdir.png` (camera placed in the walk direction, −Z, looking back):
  we see the **back** of the head/body. Render `tp_front.png` (camera at +Z): we
  see the **face/chest**. Movement is −Z → the character moonwalks.

What good requires: rotate the BodyRig 180° about Y when parenting (face the rig's
+Z toward the player's −Z forward), e.g. `body_rig.rotation.y = PI`, OR flip the
convention so the rig's forward axis is treated as +Z everywhere (camera,
yaw-to-basis, vault rays). Pick one forward convention and make rig, camera, and
movement basis agree. Fixing this also moves the head out of the FP camera's
forward cone, interacting with Finding 1.

## FINDING 3 — Locomotion + clip animation DO play (symptom misattributed)  **[want]**

"Snaps to neutral / broken movement anims" is not borne out by the data:
- Motion-Matching DB loads (`locomotion_mm.res`, 8640 frames); matcher resolves a
  **zero goal → idle frame 4646** and an **8 m/s goal → run frame 158**
  (`body_rig.gd:1269-1303`). Distinct frames ⇒ MM is selecting, not frozen.
- Clip DB loads (`bdcc2_clips.res`, 15 clips incl. idle/wave/talking/sit). `wave`
  plays and the overlay weight eases to 0.64 over 10 frames
  (`body_rig.gd:1184-1242`). Idle-fidget scheduler is wired (`:1187-1205`).
- Idle micro-life (breathing/sway) advances (`_idle_micro`/`apply_micro_life`,
  `:1311-1401`) — breathing works.

BUT the *visible* locomotion pose is weak: at 8 m/s the matched run frame yields
only ~9° hip swing (upperleg01.L quat ≈ (−0.077,0.079,−0.022,0.994)). Combined
with the backward facing (Finding 2), the legs appear to shuffle rather than
stride, which reads as "broken anim" to a player. Likely the perceived breakage is
**Finding 2 (moonwalk) + subtle MM amplitude**, not a playback failure. Worth
verifying the retarget amplitude against the source 100STYLE clips once orientation
is fixed (tests are the spec — re-check `body_rig` golden traces hold).

## FINDING 4 — Parkour tab is NOT hard-trapped; the friction is soft  **[want]**

Escape handoff is correct: `launcher._input` (`launcher.gd:117-123`) consumes
Escape **only while the mouse is CAPTURED**, releasing it to VISIBLE before the
parkour pause menu's `_unhandled_key_input` (`pause_menu.gd:42-51`) can see it, so
the top bar becomes clickable. Simulated round-trip (creator→parkour→Escape→creator)
succeeds: mouse goes VISIBLE(0)→CAPTURED(2)→VISIBLE(0), and `switch_to` frees the
old scene and resets mouse mode (`launcher.gd:80-104`).

Residual friction (the likely source of the "trapped" report):
- The bar is unreachable until you *know* to press Escape; there is no on-screen
  affordance. The discovery cost reads as a trap.
- After releasing capture, **left-clicking anywhere in the 3D viewport re-captures
  the mouse** (`interpreted_player.gd:328-334`), so a stray click re-locks you out
  of the bar. The bar buttons themselves still consume their own clicks, so
  clicking a button works — but clicking *near* it (empty viewport) re-captures.

What good requires: a persistent visible hint ("Esc to release cursor"), and/or
make the top-bar CanvasLayer eat clicks in its hit area so a near-miss doesn't
re-capture, and/or only re-capture on click **inside the 3D content rect** rather
than the whole window.

---

## SECONDARY (observed, out of explicit scope)

- **Hair renders as an upward/backward spike, not draped** (visible in all three
  renders — a dark spiky mass off the crown). Likely the injected hair01/02/03
  spring chain or the CC0 cap seating; secondary-motion (`_register_part_springs`
  / `_make_spring`, `body_rig.gd:435-476`) drives the cap. **[fix]** — needs its
  own pass; not diagnosed in depth here.
- **Feet not at y=0**: foot bone head is at y=0.072 and toes carry the lowest
  geometry; the rig drop of exactly `−stand_height` (`interpreted_player.gd:191`)
  assumes feet at local y=0. Minor planting offset; foot-IK masks it on the
  procedural path but foot-IK is **skipped under MM** (`body_rig.gd:1076-1082`),
  so under the live MM path feet may hover/sink slightly. **[want]** verify ground
  contact under MM.
- `eye_height()` reads `get_bone_global_pose` (current posed transform), but is
  called once in `_ready` before any pose, so it effectively reads rest — fine
  today; fragile if ever re-called mid-pose. **[want]** prefer `get_bone_global_rest`.
