# BDCC2 rigged accessory part meshes — © 2025 Rahi (MIT)

These `.glb` files are the **actual rigged accessory meshes** (ears, tails, horns) mined
from **BDCC2** by **alexofp / Rahi**, used as-is per BDCC2's README ("use as a base for
your own game").

- License: **MIT**, **Copyright (c) 2025 Rahi**. Full text: repo-root `NOTICE.md`.
- Upstream path: BDCC2 `Mesh/Parts/{Ear,Tail,Horn}/<Style>/<Name>.glb`.
- aeriea claims **no ownership**; these remain © 2025 Rahi under MIT.
- Only the GLB geometry (+ per-GLB `Skeleton3D` where present) is mined. BDCC2's
  wigglebone addon, `doll_attach_to.gd` attach hub, and shaders are NOT used — aeriea
  attaches each part under the appropriate aeriea (CC0 MakeHuman) bone via a
  `BoneAttachment3D` and drives the swaying ones with its own spring-bone physics
  (`scripts/body/spring_bone.gd`), registered via `BodyRig.apply_part(slot, id)` and the
  `PartLibrary` registry (`scripts/body/part_library.gd`).
- Courtesy note: confirming the art reuse with Rahi is an outstanding nicety (the owner
  accepts the MIT art-license under attribution), not a blocker.

## Files

- `ears/` — FelineEarL/R (FluffyEar), RoundEarL/R, SmallEarL/R. Each L/R GLB ships its own
  little `Skeleton3D` (Root + Ear [+ Tip]); aeriea attaches both under the `head` bone and
  sways the non-Root bones.
- `tails/` — FluffyTail, DragonTail, FelineTail (LongTail), HugeFluffyTail, PaintbrushTail.
  Each ships a `DEF-Tail1..N` + `DEF-Root` chain; aeriea attaches under `spine05` (the
  pelvis-base joint) and sways the whole chain.
- `horns/` — Horn1L/R, HornChaosL/R. RIGID (a bare `MeshInstance3D`, no skeleton in the
  GLB); aeriea attaches them under `head` and does NOT sway them (horn is bone).

## Core-body RE-SKINS (`reskin/`)

The `reskin/*.res` files are **committed `ArrayMesh` artifacts** produced by
`tools/bdcc2_head_reskin.gd` from BDCC2's **core-body HEAD** part meshes
(`Mesh/Parts/Head/{CanineHead,FelineHead}/*.glb`, © 2025 Rahi, MIT, "use as a base").

- `canine_head.res`, `feline_head.res` — the gross animal-head shell + cheek fluff, with
  each vertex's BDCC2 bone influences **rebound onto aeriea's own 169-bone MakeHuman
  skeleton** via `scripts/body/bdcc2_bone_map.gd` (the keystone map). The BDCC2 head rig is
  head-LOCAL (`DEF-Head` is its root; jaw/mouth/eye/brow bones are its children), and the
  shell is ~99% `DEF-Head`-weighted — so the faithful transfer collapses every head bone to
  aeriea's `head` bone. The result is skinned to aeriea's `head` bone (single-bind skin) and
  **DEFORMS with the body** via aeriea's own LBS (it rides the head bone when the skeleton
  poses/nods), a true weight-transfer — not a static `BoneAttachment3D`.
- Seating bakes BDCC2's `DEF-Head` origin onto aeriea's `head` bone global rest and yaws the
  mesh 180° (BDCC2 heads face −Z; aeriea faces +Z). These are deterministic, byte-reproducible.
- aeriea claims **no ownership**; the geometry remains © 2025 Rahi under MIT. Facial detail
  meshes (eyes/teeth/tongue/brows/lashes) are NOT transferred — those need the unmapped
  facial sub-bones and are aeriea's own proxy/face-rig concern.
- Wired via the `head` core-body slot in `PartLibrary` + `BodyRig.apply_part("head", id)`.

## Seating

BDCC2 authored each part against its own skeleton's attach point (`ear.L`/`tail`/`horn.L`),
offset from the bone origin. aeriea attaches to the equivalent MakeHuman bone ORIGIN, so
each part row in `PartLibrary` carries a bone-local `offset` (metres) that re-seats the
BDCC2 frame onto aeriea's anatomy (head-sides for ears, head-top for horns, pelvis-back for
tails). These offsets are tunable cosmetic data, not part of the upstream art.
