# Decision: World scale and units — 1 Godot unit = 1 meter, real human avatar

Status: **decided** (2026-05-31)

Scope: the canonical scale/units convention for the whole project, the
reference avatar dimensions, and the diegetic framing of heightened
movement. This doc is the source of truth for "how big is a thing in
aeriea." Movement *architecture* lives in `movement-substrate.md`; the
*numbers* and their real-world meaning live here.

---

## Why this exists

VR is a first-class target (DESIGN.md, *Platforms and presentation*), and
the single non-negotiable goal is 100% immersion (DESIGN.md, *The single
non-negotiable goal*). In VR the world is rendered in **real meters** to
the headset: a 1.75 m doorway that is secretly 2.3 engine-units tall reads
as *wrong* to the body even before you can name why. Presence collapses on
scale mismatch. So scale is not a free tuning knob — it is pinned to
reality, and every dimension in the project is expressed in that frame.

The corollary: the avatar is built at **real human dimensions**, and the
*heightened* feel of the movement (big jumps, wall-runs, bullet jumps) is
achieved by giving a real-scale body **superhuman capability**, not by
shrinking the world or inflating an arcade "feel" multiplier onto a
human-normal body. The body is real size; what it can *do* is above
baseline, and that is framed diegetically (see "Diegetic framing" below).

---

## The convention

- **1 Godot unit = 1 meter.** Everywhere. Positions, collider sizes, level
  geometry, ray lengths, speeds (m/s), accelerations (m/s²).
- **Gravity is real: 9.8 m/s²** — Godot's project default
  (`physics/3d/default_gravity`, unset → 9.8). The movement sim multiplies
  this by `gravity_scale` (a *diegetic capability* knob, not a units fudge;
  see the magnitude table).
- **Speeds are m/s; accelerations are m/s².** A param named `walk_speed:
  5.5` means 5.5 m/s.
- **Avatar at real human scale** (dimensions below).

### Body origin

**Current setup: the body origin sits at the capsule CENTER**, not at the
feet. In both `scripts/player_controller.gd` and
`scripts/movement/interpreted_player.gd` the `CapsuleShape3D` is centered
on the `CharacterBody3D` origin (`_collision_shape.position = Vector3.ZERO`,
`_capsule.height = stand_height * 2.0`), so the origin is `stand_height`
(0.9 m) above the feet and the capsule spans `[-0.9 m, +0.9 m]` around it.
Crouch/stand resize keeps the **feet** planted by shifting the origin
(`global_position.y -= shrink * 0.5`).

The camera pivot is a child at `position.y = camera_height_stand` (0.85 m),
i.e. **0.85 m above the center origin**, putting the eye at `0.9 + 0.85 =
1.75 m above the feet`.

**VR flag (open item, not changed here):** for VR, a **floor/feet-relative
origin** is normally what you want — the OpenXR tracking space and the
room-scale floor are defined relative to the floor, and a center origin
forces a constant `stand_height` offset into every headset-to-world
mapping (and a *moving* offset whenever the capsule resizes on crouch). The
current center-origin is coherent at 1u=1m and correct for the flat build,
but **the VR seam should revisit moving the body origin to the feet** so
the floor plane maps directly. Recorded here as a deliberate open question;
not in scope for this audit (it touches the camera rig, the crouch resize
math, and the spawn transforms, and there is no VR rig yet to validate
against).

### Reference avatar dimensions (meters)

| dimension | param | value (m) | real-human baseline | note |
|-----------|-------|-----------|---------------------|------|
| standing total height | `stand_height` × 2 | **1.8** | ~1.7–1.8 m adult | capsule total height (centered, ±0.9 m) |
| crouch total height | `crouch_height` × 2 | **1.2** | ~1.2–1.3 m crouched | capsule total height when crouched |
| eye height (standing) | center + `camera_height_stand` | **1.75** | ~1.6–1.7 m | 0.9 (center) + 0.85 (pivot); sits 0.05 m under the 1.8 m capsule top |
| eye height (crouched) | center + `camera_height_crouch` | **1.45** | ~1.2–1.4 m | render-side; eye lerps to this in slide/crouch |
| capsule radius | `_capsule.radius` | **0.35** | ~0.25–0.35 m shoulder/torso half-width | hardcoded in both controllers |

All coherent at 1u=1m. Eye at 1.75 m reads as a tall-ish but real adult;
crucially it sits **just under** the 1.8 m capsule top, so the eye cannot
see through a ceiling collider that the capsule itself is blocked by (the
no-clipping property), while still being a realistic standing eye level
(not an accidentally-low crawling height). See the audit below.

---

## Movement magnitudes — real values, human baselines, multipliers

The sim's effective fall gravity is `9.8 × gravity_scale = 9.8 × 2.2 =
**21.56 m/s²**` (≈2.2× real). The table below reads every headline
magnitude in real units against a rough real-human baseline, so the degree
of superhuman capability is **explicit and intended**, not hidden in a
"feel" fudge.

| capability | param(s) | aeriea value | real-human baseline | ≈ multiplier |
|------------|----------|--------------|---------------------|--------------|
| walk speed | `walk_speed` | 5.5 m/s | ~1.4 m/s walk / ~3 m/s jog | ~2–4× |
| sprint speed | `sprint_speed` | 10.0 m/s | ~5–6 m/s recreational run; ~10 m/s = elite 100 m sprinter peak | ~1.7–2× sustained |
| jump apex height | `jump_velocity` 9.5, eff. gravity 21.56 | **≈2.09 m** (`v²/2g`); higher with floaty-apex hold | ~0.4–0.5 m standing vertical | ~4–5× |
| jump-up velocity | `jump_velocity` | 9.5 m/s | ~3.1 m/s for a 0.5 m jump | ~3× |
| bullet-jump launch | `bullet_jump_impulse` 13.0, `bullet_jump_base_up` 6.0 | 13.0 m/s along aim + 6.0 m/s up | n/a (no human analogue) | superhuman by construction |
| wall-run speed | `wall_run_speed` | 9.0 m/s | n/a (humans cannot wall-run) | superhuman by construction |
| wall-jump | `wall_jump_lateral` 6.5, `wall_jump_up` 8.0 | 6.5 m/s out + 8.0 m/s up | n/a | superhuman by construction |
| max slide speed | `max_slide_speed` | 22.0 m/s | n/a (downhill carve cap) | superhuman by construction |

The effective gravity being ~2.2× real is part of the same diegetic
package: a heavier, snappier fall that keeps the big jumps from feeling
floaty. It is a **capability/feel parameter expressed in real units**, not
a rescaling of the world — the *world* is still 9.8 m/s² in its bones; the
avatar's traversal kit applies a scale, exactly as it applies a superhuman
jump velocity.

### Diegetic framing (NOT an arcade fudge)

These magnitudes are **intentionally above baseline-human**. The framing is
that the avatar is a **superhuman / augmented body** — a ~2 m vertical leap
and a wall-run are *what that body can do*, the way a Warframe or a parkour
protagonist's body just can. This is deliberately **not** "we exaggerated a
normal human for arcade feel." The world stays real-scale and real-gravity
*so that* the superhuman capability reads as a property of the *character*,
which is the whole point of an embodied power fantasy.

**Open question (deferred — do not invent lore here):** the precise
in-fiction justification for *why* the avatar is superhuman —
augmentation? species? setting lore? — is a broader design/lore question
that links to the power-fantasy/lore design (DESIGN.md, *Variety of power
fantasies*). It is **not decided in this doc.** What is decided: the
movement magnitudes are intentionally superhuman, expressed in real units,
and their in-fiction grounding is owned by the lore design when it lands.

---

## Audit (2026-05-31): params checked against 1u=1m

What was checked and the verdict:

- **Avatar dimensions** — coherent. `stand_height 0.9` → 1.8 m capsule,
  `crouch_height 0.6` → 1.2 m, radius 0.35 m, eye 1.75 m. All real-human
  sensible. **No change needed.** The capsule is *not* secretly 1.2 m tall;
  the eye is *not* secretly a crawling height. Both no-clipping (eye 1.75 m
  < capsule top 1.8 m) and realistic eye level hold simultaneously, so the
  earlier camera-eye-height clipping fix and a real eye level are
  *already* mutually satisfied — nothing to reconcile.
- **Camera-eye-height clipping fix** — still correct. Eye sits 0.05 m below
  the standing capsule top, so any ceiling that stops the capsule also
  blocks the eye → no see-through. Verified in the live scene under the
  highest platform (see audit verification).
- **Movement magnitudes** — left as-is (intentional, now documented as
  superhuman). Jump apex ≈2.09 m, sprint 10 m/s, etc. These are the
  deliberately-heightened feel and are **not** accidental incoherence.
- **Test level geometry** (`scenes/test_level.tscn`) — sensible at 1u=1m:
  - Platform top surfaces (box center y + half of 1 m thickness): Low
    1.0 + 0.5 = **1.5 m**, Mid 2.5 + 0.5 = **3.0 m**, High 4.5 + 0.5 =
    **5.0 m**. With a ≈2.1 m base jump apex (more with momentum + floaty
    hold + air-strafe + platform-to-platform chaining), these are a
    deliberate escalating-traversal sequence — reachable by chaining, not
    by a single standing jump, which is the intended parkour design. Not
    absurd; left as intentional.
  - Wall-run walls: 18 m long × 5 m tall, faces at x = ±3.0 with a 0.35 m
    capsule radius → ~2.65 m corridor half-gap. Fine.
  - Vault block: 1.4 m tall — within the vault height window
    (`vault_height <= 1.6` in `host_check_vault`). Reachable. Fine.
  - Gap platforms: tops at 0.5 + 0.5 = 1.0 m, 13 m apart center-to-center
    (z −5 vs −18). A 13 m horizontal gap at sprint 10 m/s with a ~2 m apex
    is a long but intentional momentum-gap-jump test. Left as intentional.
  - Ground is an 80×80 m plane, top surface at y = 0. Spawn at y = 1.5
    (origin 0.9 above feet → feet at 0.6, settles to 0). Fine.

**Net: no params were wrong-by-accident.** The dimensions, eye height, and
geometry are already coherent at 1u=1m; the heightened movement is
intentional and is now documented as diegetically superhuman rather than
left as an unexplained "feel" number. The one substantive forward item is
the **body-origin-at-feet question for VR**, recorded above as an open
seam, not changed in this pass.

---

## Verification

- Behavioral suite (`tests/movement_behavior_test.gd`) run headless under
  xvfb — green. Capsule assertions are *relative* (`crouch_h < stand_h`),
  so the documented dimensions need no assertion changes.
- Golden traces (`tests/golden_trace_test.gd`) — interpreter == compiled ==
  determinism-repeat, green. No kit params changed, so no regeneration was
  required.
- Live scene under xvfb — screenshotted standing on flat ground (eye level
  reads as a real adult, horizon at mid-frame) and under the highest
  platform (no see-through; the ceiling collider occludes as expected).
</content>
</invoke>
