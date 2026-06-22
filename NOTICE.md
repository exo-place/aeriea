# NOTICE — third-party attributions

aeriea incorporates code and assets from third parties. This file records the
attributions required by their licenses.

## BDCC2 — facial expression rig (MIT)

The facial **expression rig** under `scripts/body/face/` is ported (Path A: mined
as a replaceable surface behind aeriea's own `apply_expression(ExprState)` seam)
from **BDCC2** by **alexofp / Rahi**.

- Upstream: BDCC2 `Game/Doll/FaceAnimator/` (`face_animator.gd`,
  `FaceGestureBase.gd`, `Util/FaceValue.gd`, `Util/FaceAnimatorOverrideProfile.gd`,
  `Gestures/Blinking.gd`, `Gestures/LookDir.gd`, `Gestures/Talking.gd`).
- License: **MIT**, **Copyright (c) 2025 Rahi**.

Ported files (`scripts/body/face/face_value.gd`, `face_gesture.gd`,
`face_override_profile.gd`, `face_rig.gd`, `gestures/blinking.gd`,
`gestures/look_wander.gd`, `gestures/talking.gd`) carry the copyright notice in
their headers. Per the MIT license, the full text follows:

```
MIT License

Copyright (c) 2025 Rahi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Scope note (Path A discipline):** only the rig CODE is mined. BDCC2's `Doll` /
`BaseCharacter` hub, `GlobalRegistry`, skin compositor (`MyLayeredTexture`), and
`LayeredAnimPlayer` are NOT adopted. No BDCC2 **art** (head GLB, baked face
blendshape clips, textures) is used — the rig drives aeriea's own CC0 MakeHuman
head. The conversational-emotion adapter (`gestures/affect_expression.gd`) and
the ExprState seam are aeriea-authored, not from BDCC2.

## BDCC2 — sim systems: clock, memory, mood, relationship (MIT)

aeriea's deterministic NPC-history stack under `scripts/sim/` is ported (Path A:
mined as replaceable surface behind aeriea's own seams) from **BDCC2** by
**alexofp / Rahi** (MIT, **Copyright (c) 2025 Rahi**; full text above).

- `scripts/sim/sim_clock.gd` — from BDCC2 `Game/Systems/MemorySystem/TimeManager.gd`
  (the frame-delta `_physics_process` accrual + `Network`/`Bins` networking cut;
  time advances off aeriea's seeded timeline via `advance()`).
- `scripts/sim/memory.gd` — from BDCC2 `Game/Systems/MemorySystem/`
  (`MemoryBase.gd`, `MemoryEntry.gd`, `MemoryHolder.gd`). `GM.main.timeManager` ->
  injected SimClock; `GlobalRegistry.getMemory` -> aeriea def table; `WeakRef`
  character back-pointers -> plain id keying; `ReactionSystem`/`Bins`/`Log` dropped.
- `scripts/sim/mood_values.gd` — from BDCC2 `Game/PawnAI/Mood/MoodValues.gd`
  (the MoodStat-enum switch + chained setters dropped; pure additive scalar bank).
- `scripts/sim/relationship.gd` + `scripts/sim/mood.gd` — from BDCC2
  `Game/Systems/RelationshipSystem/` + `Game/PawnAI/Mood/MoodHandler.gd` (the
  `GM.GB` balance consts -> aeriea data; `characterRegistry`/`CharacterPawn` ->
  id keying; `Network`/`Log` dropped; Mood's output is an aeriea `ExprState`).

`scripts/sim/memory_defs.gd` (the memory-type library AS DATA) is aeriea-authored,
replacing BDCC2's `GlobalRegistry` memory registry.

## Gaze (`scripts/body/face/gaze_rig.gd`) — NOT third-party

The gaze rig is aeriea-authored, backed by Godot's **built-in** `LookAtModifier3D`
pattern (engine-native since 4.4). **No BDCC2 code is mined here** — BDCC2's
`doll.gd` only showed the chest->neck->head wiring pattern, which is an idea, not
code. Listed here only to record that this file is deliberately attribution-free.

## BDCC2 — rigged hairstyle meshes / ART (MIT)

aeriea's swappable hairstyles under `assets/body/hair/bdcc2/` are the **actual rigged
hair meshes** mined from **BDCC2** by **alexofp / Rahi** (MIT, **Copyright (c) 2025
Rahi**; full license text above). They are used as-is per BDCC2's README invitation to
"use as a base for your own game." This is BDCC2 **art** (unlike the Path-A code mining
elsewhere in this file) — the owner accepts BDCC2's MIT art-license under attribution;
a courtesy confirmation with Rahi about the art reuse is an outstanding nicety, not a
blocker.

- Upstream: BDCC2 `Mesh/Parts/Hair/*/<Name>.glb` (the GLB geometry + skeleton only;
  BDCC2's wigglebone addon and Kajiya-Kay hair shader are NOT mined — aeriea drives the
  bones with its OWN spring-bone physics, `scripts/body/spring_bone.gd`).
- Mined GLBs (15): `Ponytail1`–`Ponytail4`, `PonytailsBack`, `LongHair`, `LongCuteHair`,
  `LongChaosHair`, `LongSideHair`, `LongHairBow`, `ShortHair`, `ShortHair2`, `SideHair`,
  `FerriHair`, `CoolBangsHair`.
- Each GLB ships its own little `Skeleton3D` (a `Root` bone + 1–6 physics bones such as
  `Tail1`/`Back.L`/`Front.R`/`WiggleL`/`Bang.L`); aeriea attaches that skeleton under the
  character's `head` bone (`BoneAttachment3D`) and registers a `SpringBone` on every
  non-`Root` bone, so aeriea's spring physics sways BDCC2's geometry. Swap surface:
  `HairLibrary` (`scripts/body/hair_library.gd`) + `BodyRig.apply_hairstyle(id)`.

Some BDCC2 hair scene node names hint at per-asset contributors (e.g. `KidlatHair`,
`ArticaHair`, `FerriHair`). BDCC2 records no separate per-mesh contributor credits in its
repo beyond the project-wide MIT copyright to Rahi; if upstream later documents individual
hair-mesh authors, they should be added here.

aeriea claims **no ownership** of these meshes; they remain © 2025 Rahi under MIT.

## BDCC2 — rigged accessory part meshes / ART (MIT)

aeriea's swappable accessory parts (ears, tails, horns) under `assets/body/parts/bdcc2/`
are the **actual rigged meshes** mined from **BDCC2** by **alexofp / Rahi** (MIT,
**Copyright (c) 2025 Rahi**; full license text above). Used as-is per BDCC2's README
invitation to "use as a base for your own game." This is BDCC2 **art** (like the hairstyles
above) — the owner accepts BDCC2's MIT art-license under attribution; a courtesy
confirmation with Rahi about the art reuse is an outstanding nicety, not a blocker.

- Upstream: BDCC2 `Mesh/Parts/{Ear,Tail,Horn}/*/<Name>.glb` (GLB geometry + per-GLB
  skeleton only; BDCC2's wigglebone addon, `doll_attach_to.gd`, and shaders are NOT mined
  — aeriea drives the swaying parts with its OWN spring-bone physics,
  `scripts/body/spring_bone.gd`).
- Mined parts: **ears** — FelineEar L/R, RoundEar L/R, SmallEar L/R; **tails** — Fluffy,
  Dragon, Feline (LongTail), HugeFluffy, Paintbrush; **horns** — Horn1 L/R, HornChaos L/R.
- Generalized swap surface: `PartLibrary` (`scripts/body/part_library.gd`) + the slot-based
  `BodyRig.apply_part(slot, id)` — the generalization of the former hair-only swap. Tail/ear
  GLBs ship their own `Skeleton3D` (DEF-Tail1..N / DEF-Ear.* etc.) which aeriea attaches
  under the matching MakeHuman bone (`head` for ears/horns, `spine05` for tails) via a
  `BoneAttachment3D` and sways with a `SpringBone` per non-Root physics bone. Horns are
  rigid in BDCC2 (no skeleton) — attached but not swayed (correct: horn is bone).

See `assets/body/parts/bdcc2/NOTICE.md` for the per-asset list + the seating-offset note.

aeriea claims **no ownership** of these meshes; they remain © 2025 Rahi under MIT.

## BDCC2 — animation CLIPS, retargeted onto the MakeHuman rig / ART (MIT)

aeriea's mined animation library `assets/body/bdcc2_clips.res` (a `ClipDB`) holds the
**actual animation clip data** mined from **BDCC2** by **alexofp / Rahi** (MIT,
**Copyright (c) 2025 Rahi**; full license text above) and **retargeted** (not rebuilt)
onto aeriea's CC0 MakeHuman 169-bone rig. Used as-is per BDCC2's README invitation to
"use as a base for your own game." This is BDCC2 **art/data** (like the hair/part meshes
above) — the owner accepts BDCC2's MIT art-license under attribution; a courtesy
confirmation with Rahi about the clip reuse is an outstanding nicety, not a blocker.
aeriea claims **no ownership** of these clips; they remain © 2025 Rahi under MIT.

- Upstream: BDCC2 `Anims/Raw/{LocomotionAnims,GestureAnims,BasicAnims}.glb` (the per-bone
  rotation TRACKS only). aeriea does **NOT** adopt BDCC2's animation ARCHITECTURE — its
  `LayeredAnimPlayer` addon, AnimationTree graph, `GlobalRegistry`, `DollAnim*` defs, or
  the Path-B layering. Only the clip DATA is mined; aeriea drives it with its OWN clip
  layer (`BodyRig._apply_clip_layer` + `AnimationPlayer`-free pose stamp).
- Retarget: BDCC2's anim rig uses clean Blender names (`hips`, `thigh.L`, `upper_arm.L`,
  `forearm.L`, ...) — **not** Rigify `DEF-*` (those appear only in BDCC2's PART GLBs).
  The map `scripts/body/bdcc2_bone_map.gd` (DATA) carries BDCC2→MakeHuman names; the
  retarget (`tools/bdcc2_clip_ingest.gd`) transfers each bone's GLOBAL orientation
  relative to its bind, de-yaws the root (facing is aeriea's sim-owned), and re-expresses
  it MH-bone-local — so the two rigs' differing local axis frames cancel.
- Mined SFW clips (15): idle variants `idle` / `idle_long` / `idle_long_idle` /
  `idle_sexy`; gestures `wave` / `head_nod` / `head_shake` / `talking` / `talking_one` /
  `shrug` / `sigh` / `look_away` / `happy_hands` / `thinking`; fidget `sit`. Idle variants
  auto-play as standing fidgets; gestures are one-shot emotes (`emote` input → `wave`).
  BDCC2's NSFW sex-scene / restraint clips are deliberately **not** mined into this
  walk-around set — they belong to a separate intimacy context (available, not wired).

## MakeHuman — base mesh, rig, proxies, targets (CC0-1.0)

aeriea's body/head mesh, skeleton, proxies, and morph targets derive from
**MakeHuman** (makehumancommunity/makehuman v1.3.0), released **CC0-1.0**. See
`assets/body/base_body.manifest.json` and `assets/body/base_body_proxies.index.json`.
