# Diagnosis — cosmetic parts + hair

Area: `scripts/body/part_library.gd`, `scripts/body/body_rig.gd` (apply_part / accessory
attach / BoneAttachment), `assets/body/parts/bdcc2/*.glb`, hair GLBs under
`assets/body/hair/bdcc2/`, spring driving in `scripts/body/spring_bone.gd`.

Method: read the code; extracted GLB node transforms + POSITION accessor bounds with a glTF
parser; read the rig JSON for head/spine05 bone origins; ran two runtime probes (manual
`apply_pose` vs. real `_process`-driven) under xvfb to measure where parts actually land;
rendered several frames to confirm visually. Evidence cited inline.

---

## FINDING 1 — The default CC0 "cap" hair is a long mid-back/chest drape, not a scalp cap. **[fix / redesign]**

This is the dominant, always-present defect — the "detached, rigid, blocky sheet/clump" in
the renders is THIS, not a BDCC2 hairstyle. The hair-slot default is `cap` (PartLibrary
`HAIR_CAP`, `part_library.gd:53,75`), so every body renders it unless a BDCC2 style is chosen.

Evidence (runtime probe, cap active): the proxy mesh "hair" surface spans
**ymin=1.06 … ymax=1.71** (428 verts). The skull crown is ~y1.66–1.71; y1.06 is sternum
level. So the cap geometry hangs ~60 cm down the FRONT of the torso, over the face and chest
— exactly the black sheet seen in `/tmp/diag_full.png` and `/tmp/diag_ears.png`.

Root cause is authored-geometry, stated in the pipeline itself:
`tools/body_proxy_build.gd:99` — *"the CC0 `helper-hair` group is a real scalp cap that
drapes to mid-back."* The cap is re-skinned onto an injected `hair01/02/03` chain by vertical
band (`_skin_hair_chain`, `body_proxy_build.gd:218`), and the spring layer only adds *sway*
around those bones (`spring_bone.gd:47` rotates the bone; it cannot reshape a drape onto the
skull). Nothing pins the drape to the head silhouette, so it reads as a flat curtain.

What good requires: either (a) author/clip the helper-hair group to an actual scalp cap (trim
the mid-back drape verts in `body_proxy_build`), or (b) retire `cap` as the default and ship a
real short BDCC2 style as the hair default. The current default cannot read as hair-on-a-skull
no matter how the springs are tuned. (Pure "fix" if just clipping geometry; "redesign" if the
default-hair choice is reconsidered.)

---

## FINDING 2 — BDCC2 hairstyles attach at the head BONE ORIGIN with NO vertical seat correction → hair sits too low, drapes over the face. **[fix]**

Hair is the one accessory slot with NO entry in `ACCESSORY_SEAT_TARGET`
(`body_rig.gd:631-634` lists only `SLOT_EARS` and `SLOT_HORNS`). So for a BDCC2 hair GLB,
`_accessory_seat_offset` returns `Vector3.ZERO` (`body_rig.gd:643-644`) and `_attach_one_glb`
applies `transform = Transform3D(scale=1, offset=ZERO)` (`body_rig.gd:610-615`). The hair mesh
origin is pinned directly to aeriea's `head` bone origin.

Evidence: aeriea `head` bone origin = **(0, 1.514, 0.016)** (`base_body_rig.json`, head bone
`head:[0,1.514255,0.016075]`, basis identity — loaded identity at `body_rig.gd:316`). BDCC2
hair POSITION bounds are authored centered ~origin relative to *BDCC2's* head joint, e.g.
ShortHair.glb min=[-0.125,-0.123,-0.135] max=[0.138,0.239,0.154]; LongHair.glb
min y=-0.306 max y=0.233. With a zero offset, the hair's y-center sits AT 1.514 (the
skull/neck base), so the bulk of the cap hangs from there downward over the face — confirmed
in `/tmp/diag_hair_short_feline.png` (short hair draping over the eyes/cheeks). BDCC2's own
head joint sits higher inside the skull than MakeHuman's `head` joint (which is at the
skull base / neck top), so the BDCC2-authored offset-from-joint lands low on the MH rig.

What good requires: a hair seat target (like ears/horns), i.e. add `SLOT_HAIR` to
`ACCESSORY_SEAT_TARGET` (or a per-style offset), lifting the hair so its crown sits at the MH
skull top (~y1.66) and its center over the cranium, not the neck base. Per-style tuning is
likely needed (long vs short have different mesh centers). Unverified: the exact target
vector — it must be tuned against renders, not derived blindly, because hair is not a
point-anchored accessory (the AABB-center recenter that works for a compact ear will pull a
long ponytail's center up into the skull). Hair may warrant a "crown-align" rule (align mesh
MAX-y to skull top) rather than the center-on-target rule used for ears/horns.

---

## FINDING 3 — The "ear displaced to upper-left" is a TWO-part story; the seat math is sound, the displacement is an idle-pose + harness-lag effect. **[fix + want]**

Reported symptom confirmed in `/tmp/diag_full.png` / `/tmp/diag_ears.png`: a single
skin-coloured fluffy ear floats up-and-left, detached from the head.

What I verified:
- The seat math LANDS the ear correctly. Runtime probe (feline ears only): FelineEarL renders
  at WORLD center **(0.078, 1.594, 0.016)** and FelineEarR at **(-0.078, 1.594, 0.016)** —
  symmetric, head-side, ear-height, both present (`body_rig.gd:642-652` recenter using
  `ACCESSORY_SEAT_TARGET[ears] = {L:(0.085,0.10,0), R:(-0.085,0.10,0)}`, `body_rig.gd:632`).
  The L/R filename detection works (`body_rig.gd:645`). So placement-by-rest is NOT broken.
- The "detached, single, upper-left" appearance in my STATIC renders is a **harness artifact**:
  the render/probe drove the pose via manual `BodyRig.apply_pose()` calls, under which the
  Skeleton3D never fires its pose-update notification, so the `BoneAttachment3D` stayed pinned
  to the head's REST transform while the body mesh used the animated pose. Under a real
  `_process`-driven loop the attachment DOES track the animated head: probe measured head
  animated origin (-0.002, 1.521, **-0.075**) and the ear attachment origin matched it exactly
  (-0.002, 1.521, -0.075). So in-game the ears ride the head.

Residual real defects this exposes:
- **[fix]** The idle/clip animation leans the head forward ~9 cm in z (rest z=+0.016 →
  animated z=-0.075). The ear seat TARGET is expressed in the head's REST basis/origin
  (`body_rig.gd:650` uses `get_bone_global_rest`), tuned to look right at rest; the ears then
  ride the animated head rigidly. Whether they look seated under the full idle range is
  unverified — needs a process-driven render sweep. The y-target +0.10 above the head origin
  puts ear center at y1.59–1.69; whether that hugs the actual skull-side surface (vs. floating
  off it) is unverified and should be checked against the rendered skull silhouette.
- **[want]** The render harness `tools/hair_render.gd` cannot show correct accessory seating,
  because (a) it poses via manual `apply_pose` so BoneAttachments lag a frame to REST, and
  (b) when `ears!=""` but `tail==""` it calls `cam.look_at` BEFORE `add_child(cam)`
  (`hair_render.gd:49-52`), throwing "Node not inside tree" and leaving the camera at default.
  Any visual QA of parts done through this tool is misleading. Fix: drive the rig through the
  scene tree (`_process`) for the settle frames, and add the camera before `look_at`.

---

## FINDING 4 — Slot/attach design assessment: SOUND in shape, INCOMPLETE in coverage. **[redesign — scoped]**

The data-over-code slot/part registry (`part_library.gd`) + generalized
`apply_part`/`BoneAttachment3D` attach + spring re-registration (`body_rig.gd:512-539`,
`_register_part_springs`) is a clean, correct design: one BoneAttachment per GLB tracking a
named bone, springs driving either the body skeleton (cap chain) or the GLB's own little
skeleton, rigid parts (horns) attaching without sway. The per-slot anatomical-target recenter
expressed in the bone rest basis (`_accessory_seat_offset`) is the right idea and demonstrably
works for ears.

Where it is wrong-by-omission, not wrong-by-design:
- Hair has no seat target (Finding 2) — the one slot whose default is always on and whose
  geometry is NOT point-anchorable by AABB-center the way a compact ear is. The single
  "center-on-target" rule is too weak for hair; a crown-align rule is likely needed. This is
  the seam where the otherwise-uniform recenter abstraction leaks.
- The recenter uses each part's RAW mesh-vertex AABB (`_node_geometry_center`,
  `body_rig.gd:657-675`) and ignores the GLB's own skin bind. For the BDCC2 ears this happens
  to coincide (bind ≈ inverse-rest, skeleton held at rest → rendered ≈ raw verts; probe
  confirmed). It is NOT guaranteed in general: any part whose bind pose differs from its raw
  vertex frame will be mis-centered. Unverified for tails/horns specifically. A robust version
  should center on the SKINNED rest geometry, not raw POSITION arrays.

What good requires: keep the slot/attach architecture; add a hair seat rule (crown-align),
and make `_node_geometry_center` honour the skin bind (or document the raw-verts assumption
as a hard invariant the assets must satisfy and assert it).

---

## Summary table

| # | tag | defect | evidence locus |
|---|-----|--------|----------------|
| 1 | fix/redesign | CC0 "cap" default hair drapes to chest (y1.06), not a scalp cap; it IS the floating black sheet | runtime probe hair surf ymin=1.06 ymax=1.71; `tools/body_proxy_build.gd:99` |
| 2 | fix | BDCC2 hair gets ZERO seat offset (not in `ACCESSORY_SEAT_TARGET`) → pinned to neck-base head bone, drapes over face | `body_rig.gd:631-634,643-644`; head origin (0,1.514,0.016) vs BDCC2 hair y-center ~0 |
| 3 | fix/want | ear seat math is correct (L/R land symmetric at ±0.078,1.594); "upper-left detached" was a manual-apply_pose harness lag; head idle leans z 9cm; harness `look_at` before `add_child` crashes camera | probe ear world centers; `hair_render.gd:49-52`; `body_rig.gd:650` |
| 4 | redesign(scoped) | slot/attach design sound; recenter ignores skin bind + has no hair-specific (crown-align) rule | `body_rig.gd:657-675`, `631-652` |
