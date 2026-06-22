# Body render + rig — diagnosis (DIAGNOSE ONLY)

Scope: `scripts/body/body_rig.gd`, morph pipeline (`body_state.gd`, `modifier_registry.gd`,
`detail_library.gd`, `proxy_morph.gd`), body materials, the MorphGlow node
(`character_creator.gd`), mesh+skeleton assembly. Base: MakeHuman CC0.

Method: read the listed sources; rendered the live `BodyRig` under xvfb (opengl3/llvmpipe)
at neutral default `BodyState` (age 25, masc 50). Renders saved alongside this file:
`_body_with_hair.png` (full body), `_face_3q_nohair.png` (3/4 face, hair cap hidden).
Vertex/bone/proxy bounds probed directly from the committed `.res`/`.json` artifacts.

Each finding cites a concrete `file:line` or a saved render. Where the exact mechanism is
not pinned down I say **unverified** and state what would pin it.

---

## TOP FINDINGS

### 1. The CC0 helper-hair "cap" renders as black slabs draping to the chest — it is the
###    dominant face-obscurer. **fix** (asset/usage; the "featureless face" symptom #1)

Evidence (render): `_body_with_hair.png` — long flat black planar strands hang from the
crown down the front of the torso to ~chest level, covering the entire face. This is the
neutral default body; no hairstyle was selected, so this is the *default* CC0 cap.

Evidence (geometry): the `hair` proxy surface spans **y 1.018 .. 1.666** (probed from
`assets/body/base_body_proxies.res`) — i.e. from above the crown (head bone y=1.514, top
of mesh y=1.675) down to **y≈1.02 (chest)**. The CC0 "helper hair" is a long-hair guide
mesh, not a scalp cap. It is rendered solid matte black with `cull_mode = CULL_DISABLED`
(`body_rig.gd:898-901`, `_proxy_material` "hair" branch) so both faces of the slabs draw
opaque black.

It is ON by default: `PROXY_DEFAULT_HIDDEN := {"genitals": true}` (`body_rig.gd:64`) leaves
`hair` visible; `_proxy_piece_visible` returns true for `hair` whenever the active hair part
is the CC0 cap (`body_rig.gd:835-836`), which is the slot default (`apply_part` / PartLibrary
default).

What good would require: the default body should show NO hair cap (default to bald or to a
real fitted hairstyle), OR the CC0 helper-hair mesh must be replaced with an actual short
scalp cap — the long-hair guide mesh is not a usable default.

### 2. Eye proxies render wrong (grey sclera + tiny red iris, look mis-seated) although the
###    eyeball geometry is correctly placed and sized. **fix** (the "featureless face" #2)

Evidence (render): `_face_3q_nohair.png` — the eye sockets at the correct height read as dark
empty recesses with only a faint sclera; a separate grey rectangle with a dark-red blob sits
low near the nose. The eyes do not read as eyes.

Evidence (geometry — refutes "mis-seated"): the `eyes` proxy surface is at **y 1.531..1.559,
center (0, 1.545, 0.129)**, and the rig's `eye.L/eye.R` bones are at **y 1.545, z 0.124**
(probed). So the eyeballs ARE seated in the sockets. Each eyeball AABB ≈ 28×28×20 mm — a
real, correctly-sized sphere. The proxy is skinned to eye.L/eye.R (bones 133/134) plus
oculi/orbicularis (`body_rig.gd:_build_proxies`, ProxyMorph re-bake). So the *placement* is
correct; the *appearance* is the defect.

Likely cause (**partially unverified**): the eye is only **96 verts / 172 tris for BOTH eyes**
(`assets/body/base_body_proxies.index.json`) — ~48 verts each, heavily faceted — and the iris/
pupil/sclera are computed analytically in `assets/body/eye.gdshader` from the proxy UVs
(`body_rig.gd:38-60`, `_build_eye_material` 968-973). At ~48 verts the UV parameterization is
coarse, so the analytic iris collapses to a small off-center blob and the sclera reads as a
flat grey card. The "stray shard at the nose" is most plausibly the far eyeball seen through
the empty near socket; I did not isolate it to a single triangle. To pin: render the `eyes`
surface in isolation with a flat debug material and inspect per-vertex UVs.

What good would require: either a denser eyeball proxy with a clean UV sphere param, or an
eye shader that is robust at low tessellation (and verify the sclera isn't being lit as a
flat grey card by the unshaded/lighting path).

### 3. Two-tone face/cranium seam — the central face renders noticeably darker than the rest
###    of the head and body. **fix** (unverified cause)

Evidence (render): `_face_3q_nohair.png` — the central face region (forehead-to-chin) is a
darker brown than the lighter `SKIN_ALBEDO` (0.86,0.68,0.58 — `body_rig.gd:67`) cranium/neck/
body. The whole body uses ONE `material_override = _skin_material` (`body_rig.gd:354-357`),
so a per-material split is ruled out — it is a per-fragment shading difference (normals or
ambient-occlusion-like self-shadow), not two materials.

Cause **unverified**: most likely the recomputed per-vertex normals over the dense, concave
facial region (`body_state.gd:653-665` / converter `_compute_normals`) plus the directional
light angle produce a darker facial shading; could also be that the face verts are
UV-seam-split and accumulate normals from only one side (`body_converter._compute_normals`
accumulates per render-vertex, so seam-split verts get one-sided normals — `body_converter.gd:
1118-1137`). To pin: render with flat ambient-only lighting; if the seam vanishes it's
normals/lighting, if it persists it's vertex color/AO baked into the arrays.

What good would require: uniform skin shading across the head; if it is seam normals, average
normals across UV-seam-duplicated verts in the converter.

### 4. The body is NOT low-poly and the face mesh is NOT featureless — refutes that framing.
###    **(no-bug; the perceived "low-poly/flat" is findings #1–#3)**

Evidence: base mesh = **13,380 base verts / 14,517 render verts** (`base_body.manifest.json`
"moved_vertices" 13380; `base_body_detail.index.json` render_vertex_count 14517) — the full
standard MakeHuman topology, a moderately dense human mesh. Normals are smooth area-weighted
(`body_converter.gd:1118-1137`; rebaked identically in `body_state.gd:653-665`), not flat-
shaded. With the hair cap hidden, `_face_3q_nohair.png` shows real eyelids, nose, lips, and
ears modeled in the mesh. The "low-poly/flat face" complaint is caused by #1 (hair slabs over
the face) + #2 (broken-looking eyes) + #3 (dark face seam), not by mesh density or flat
shading. The hands/feet do read slightly faceted (extremities are lower-density in the MH
base) — a **want** (higher-density or normal-mapped extremities) if it matters.

### 5. MorphGlow overlay is coincident geometry with depth-test ON — a z-fighting setup.
###    **fix** (only manifests on hover in the character creator)

Evidence: `_build_glow_overlay` (`character_creator.gd:249-264`) builds a MeshInstance3D
whose mesh is the body's exact triangles at the body's exact rest positions
(`_rebuild_glow_mesh` sets `ARRAY_VERTEX = _glow_base_pos`, the body verts —
`character_creator.gd:357-358`), with `mat.no_depth_test = false` (`:261`) and NO depth-bias /
polygon offset / normal-push. Coincident triangles at equal depth ⇒ classic z-fighting.
It is additive+unshaded (`:255-257`) so it mostly reads as a tint, and it is `visible = false`
until hover (`:263`, `_update_hover_glow`), so it only z-fights while hovering in the creator —
NOT on the neutral body in-game. The prompt's "glow z-fighting at neutral" is therefore: the
SETUP is z-fight-prone, but it is not active on a neutral non-hovered body.

What good would require: push the overlay along vertex normals by a small epsilon, or set a
depth bias / `render_priority`, or `no_depth_test = true` for the additive highlight.

### 6. Dead region-masking index-buffer machinery left behind by the BDCC-graft revert.
###    **redesign/cleanup** (not a render bug; stale code + misleading comments)

Evidence: the BDCC core-body graft + its per-region base-mesh masking subsystem were removed
in `5cb77d0`. But `body_state.gd` still carries the `base_index` / `neutral_base_index`
snapshot+restore round-trip whose ONLY purpose was that masking: `bake_morphed_normals(...,
base_index)` (`body_state.gd:604-613`) and `apply_morph_cpu` capturing/restoring
`neutral_base_index` (`body_state.gd:693-703`), with comments that still describe the deleted
system ("region masking may have dropped triangles from the live one", ":609-610";
"the rig re-applies any still-active masks AFTER this bake", ":696"). After the revert, nothing
in `scripts/body/` drops triangles from the body index buffer, so this restores the identical
full index every bake — a harmless but dead round-trip with lying comments. Verified no
core-body/mask refs remain in `body_rig.gd` (grep clean) — the revert of body_rig itself is
complete; only this body_state remnant is stale.

What good would require: drop the `base_index` parameter and the `neutral_base_index` meta, or
re-document why it is kept. (Per CLAUDE.md "retire, don't deprecate / finish migrations.")

---

## PIPELINE SOUNDNESS — confirmed OK (no defect found)

- **Skeleton assembly** (`body_rig.gd:306-360`): 169 bones (full MH default + injected
  belly/glute/hair01-03), rest computed as `parent_global⁻¹ * child_global` from JSON heads
  (`:324-331`); Skin bind = inverse global rest (`:336-338`) — standard LBS, correct. Bone
  bases are identity by construction (JSON carries head positions only, `:316`), which the MM/
  clip layers explicitly assume (`pose_quat` composed onto rest, `:1296`).
- **eye_height / head_top** (`body_rig.gd:737-767`): eye_height=1.545 (from eye bones),
  head_top=1.675 (mesh max-Y, clamped to base verts not the morph-inflated AABB, `:760-767`).
  Eye sits below crown — the camera-inside-the-head bug is genuinely fixed.
- **CPU morph + normal rebake** (`body_state.gd:604-675`, `apply_morph_cpu` 682-707): bakes
  morphed positions + recomputed outward normals into the base surface and zeros GPU blend
  weights — the documented correct path (GPU octahedral normals can't carry a delta). Bakes
  from a preserved neutral copy held in instance meta, so re-morphs are stable/non-cumulative.
  Sound.
- **Macro factor-product projection** (`body_state.gd:471-501`, `_universal_target_weight`):
  the §1.3 product over gender×age×muscle×weight×proportions tokens, fed by the sparse
  DetailLibrary CPU deltas — composes correctly (not the old single-anchor sum).
- **Age→stature curve** (`body_state.gd:137-353`): CDC-median-cited tables (`MEDIAN_CM_MALE/
  FEMALE`), sex-blended growth fraction inverted onto the morph's measured anchor-stature
  fractions; ≥25yr stays verbatim MakeHuman; continuous at the 19/25 joins. Math is internally
  consistent and the gate (`is_adult_body`, `:451-454`, `>= 18`, fail-closed on NaN) reads the
  natural-unit field, not the lossy macro. No defect found.
- **ProxyMorph** (`proxy_morph.gd:76-149`): additive on captured neutral, global→local index
  mapping per surface, outward normals same convention as the body. Sound; the eye *appearance*
  (#2) is a geometry/shader issue, not a ProxyMorph bug.
- **Proxy hide** (`_collapse_proxy_surfaces`, `body_rig.gd:845-875`): collapses hidden surfaces
  to a sub-floor point (degenerate tris) AND sets transparent material — robust hide. OK.

## NOT A BUG, by design

- Single flat `StandardMaterial3D` skin (`body_rig.gd:354-357`, albedo only, roughness 0.7,
  no normal/AO/subsurface map). Reads matte/plastic. **want** (skin shading) — intentional
  placeholder, not a correctness bug.
