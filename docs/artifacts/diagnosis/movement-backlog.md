# Movement / Parkour — defect backlog (inputs for a future MOVEMENT design pass)

**Status:** RECORDED, NOT FIXED. Bookkeeping only — no fix or design has been
done. These are user-reported defects from running the app, lightly located in
code where cheap. The MOVEMENT sandbox has had no design pass; this list is the
raw input for that pass, not a spec for it.

**Scope:** `scripts/movement/*` (`interpreted_player.gd`,
`movement_kit.gd`, `generated/compiled_base_movement.gd`),
`scripts/body/spring_bone.gd` (jiggle), `scripts/body/body_rig.gd`
(locomotion / clip layer / idle), animation/clip drive paths. Companion to the
earlier `movement.md` diagnosis (FP camera, backward facing, soft tab trap).

---

## Defects

1. **Jiggle physics completely broken.** — Soft-region jiggle is the spring-bone
   secondary-motion layer in `scripts/body/spring_bone.gd` (verlet-style damped
   spring, `step()` from ~line 48; reset/state ~lines 28-40). Driven from
   `body_rig.gd` (`_register_part_springs` / `_make_spring`, ~lines 435-476 per
   prior diagnosis). Symptom not yet root-caused — would check whether jiggle
   springs are registered at all vs. mis-tuned/mis-anchored.

2. **Walk animation completely broken.** — Locomotion pose is produced in
   `body_rig.gd` (motion-matching + procedural, `set_movement_state` /
   `_physics`-side MM resolve ~lines 1076-1303). Prior `movement.md` FINDING 3
   noted MM *does* select distinct frames but pose amplitude is weak and the
   body faces backward (moonwalk). User now reports walk as outright broken —
   would re-verify retarget amplitude and the MM/procedural blend under the live
   path once orientation (movement.md FINDING 2) is settled.

3. **Idle animations snap back to neutral when they finish (should loop/blend).**
   — Clip/idle layer in `body_rig.gd`: one-shot finish path at lines 1219-1234.
   At line 1224-1226, when a non-looping clip reaches `dur` it sets
   `_clip_idx = -1` and the weight eases out (1229) — the upper body then falls
   back to the locomotion/idle base with no cross-fade INTO the next idle, which
   reads as a snap. Idle-fidget scheduler + clip ids at ~lines 255-269.

4. **Face visible from inside the head during some idle animations.** — FP
   camera seating / culling. Related to `movement.md` FINDING 1 (camera buried
   in head mesh, `interpreted_player.gd:246-269`, no Z/face offset, `near=0.1`
   insufficient). Here the new wrinkle is anim-specific: certain idle poses
   translate the head into the camera. Would check the FP cull mask (head/face
   not excluded from the FP camera layer) and whether the camera re-seats per
   frame against the posed head bone.

5. **No walljump.** — Wall-jump IS authored in the compiled kit
   (`generated/compiled_base_movement.gd`: `P_wall_jump_*` ~lines 104-106; grace
   timer set at 235-237 / 335-346, fired when jump buffered during grace). Mirror
   in `player_controller.gd:766 _do_wall_jump`, params 150-154. User reports it
   never triggers — would check whether `wall_jump_grace` is ever armed (wall
   detection leaves `wall_detected`/`wall_normal` in `movement_kit.gd` leaf set,
   lines 23-29) i.e. whether wall contact is actually being sensed in the live
   level.

6. **Bullet jump does not work when aiming too far upward.** — Bullet jump in
   `generated/compiled_base_movement.gd` lines 283-287 / 309-313: it adds impulse
   along the `aim` space with `{ "base": "aim", "clamp_y_min": 0.0 }`. Aim/pitch
   is fed in via `interpreted_player.gd:311-321` (`interpreter.pitch = _pitch`).
   When aiming far up the aim vector's horizontal component shrinks toward zero
   and the y-component is clamped, so the launch degenerates — consistent with
   "doesn't work aiming too far up." Would confirm exact `_k_add_velocity`
   `clamp_y_min` semantics in the interpreter.

7. **Crouch move does not stop the player from falling off platform edges.** —
   Expected crouch/ledge behavior (don't walk off an edge while crouched) is
   absent. CROUCH state exists (`interpreted_player.gd:30` enum, crouch
   height/cam ~lines 60-70, 262-264) and ledge rays exist for vaulting
   (`vault_ledge_ray_high/low` ~lines 87-88), but there is no edge-stop / ledge-
   detent on the crouch path. Unverified that any "don't fall off while crouched"
   rule is implemented — would check the CROUCH branch of the kit and whether a
   floor-ahead probe gates horizontal motion while crouched.
