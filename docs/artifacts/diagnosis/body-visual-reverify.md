# Body visual re-verify — pinning the UNVERIFIED causes (VERIFY ONLY)

Follows up `body-render.md`, which flagged the eyes and the face/cranium seam with cause
**UNVERIFIED**. This pass pins the actual root causes with render evidence + per-target
coverage instrumentation. **No code was changed.** A throwaway diagnostic harness
(`tools/body_visual_diag.*`) was used to render and to dump proxy morph-follow coverage,
then deleted (untracked; not committed). Renders live in `/tmp/visual-check/`.

Method: built the live `BodyRig` under xvfb (vulkan/llvmpipe), applied `BodyState` at
masculinity 0 / 50 / 100 and height 150/200 cm, hid the CC0 hair cap, and rendered face
close-ups, a flat-ambient body (directional light off, ambient cranked — separates shading
from geometry), a back-of-head shot, and a 3/4 face. Also dumped, for each masc, which
`to_blend_weights()` keys exist and how many the proxy detail library can actually follow.

---

## 1. Facial proxies (eyes/teeth/tongue) only seated at MALE — ROOT CAUSE PINNED

**Root cause: the proxy detail library was baked against a DIFFERENT, almost-disjoint set of
macro target names than the body's `to_blend_weights()` actually emits, so the eyes/teeth/
tongue receive essentially ZERO gender/race morph and stay at the raw MakeHuman base
position while the body face surface morphs away from it.**

The proxies do NOT skin-follow the skull shape (the skull is not a bone — it is baked
vertex displacement). They follow morph only through `ProxyMorph.apply()`
(`scripts/body/proxy_morph.gd:76-149`), which adds, per surface, `Σ wᵢ·Δᵢ` from the proxy
delta library keyed by the SAME target paths the body uses (`proxy_morph.gd:82,108-127`).
So a proxy follows a given morph target **only if that exact target path exists in
`base_body_proxies_detail.index.json`.** It mostly does not:

Coverage dump (`to_blend_weights()` keys vs proxy delta library):

| masc | body targets | followed by proxy | macro targets | macro followed |
|------|-------------|-------------------|---------------|----------------|
| 0 (feminine) | 2 | **0** | 2 | **0** |
| 50 (neutral) | 4 | 1 (a tiny-weight one) | 4 | 1 |
| 100 (masculine) | 2 | 1 | 2 | 1 |

The heavy (>0.2) targets the body emits but the proxy CANNOT follow:
- masc 0: `macrodetails/caucasian-female-young.target=1.0`,
  `macrodetails/universal-female-young-averagemuscle-averageweight.target=1.0`
- masc 50: both of the above at 0.5 **plus**
  `macrodetails/universal-male-young-averagemuscle-averageweight.target=0.5`
- masc 100: `macrodetails/universal-male-young-averagemuscle-averageweight.target=1.0`

The body has **188** `macrodetails/*` targets in its detail library
(`assets/body/base_body_detail.index.json`); the proxy library has **8**
(`assets/body/base_body_proxies_detail.index.json`), and the intersection with what the
body emits at runtime is ≈0. Concretely the proxy library has `caucasian-male-young.target`
and a handful of `*female-young-MAXweight*` / proportions targets, but **none** of
`universal-male-young-averagemuscle-averageweight`, `universal-female-young-
averagemuscle-averageweight`, or `caucasian-female-young` — the exact targets the neutral/
feminine body rides.

**Why "correct only at male":** the rendered proxy base (its captured neutral) sits at the
raw `base.obj` proxy positions. The MakeHuman male-young anchor is closest to that raw base,
so at the masculine end the un-morphed proxies happen to line up with the (also near-base)
face surface. At neutral/feminine the body face has translated/reshaped but the proxies have
not — they read as displaced. Confirmed empirically: restoring the proxy to its captured
neutral and skipping `ProxyMorph` produces a **byte-identical** render to masc=50
(`bvd_face_neutralbase.png` md5 == `bvd_face_masc50.png` md5) — i.e. at neutral the proxy
morph delta is negligible; the seating you see is the un-morphed base proxy against a morphed
body. `bvd_face_masc0.png` and `bvd_face_masc50.png` are also byte-identical — the proxies
do not move between feminine and neutral at all.

Severity in the render is worse than "slightly off": at neutral the eyeballs read up near the
brows, and the teeth (white) + tongue (red) cards protrude beside/below the nose rather than
sitting in the mouth (`bvd_face_masc50.png`, `bvd_eye_closeup.png`). (Note: this is more
displaced than `body-render.md`'s 3/4 shot suggested, because that shot's geometry probe read
the STATIC `.res` neutral, not the body-vs-proxy delta after the body's own neutral morph.)

Seating/follow code: `scripts/body/body_rig.gd:717-723` (calls ProxyMorph after the body
bake); `scripts/body/proxy_morph.gd:82,108-127` (delta application keyed by target path).
The defect is in the DATA: `assets/body/base_body_proxies_detail.index.json` was built (by
`tools/body_proxy_build.gd`) against the wrong/old macro target set.

**Confidence: high** (coverage table + byte-identical-render proof + missing-target lookups).

Renders: `/tmp/visual-check/bvd_face_masc0.png`, `bvd_face_masc50.png`,
`bvd_face_masc100.png`, `bvd_face_hmin.png`, `bvd_face_hmax.png`,
`bvd_face_neutralbase.png`, `bvd_eye_closeup.png`, `bvd_face_3q.png`.

---

## 2. Eyebrows + eyes look comically bad — what they ARE + dominant cause

**Eyebrows (and eyelashes) ARE project-authored proxy mesh surfaces**, not textures: separate
surfaces `eyebrows` (32 verts) and `eyelashes` (32 verts) in the proxy mesh
(`assets/body/base_body_proxies.index.json`), rendered as thin two-sided dark-keratin cards
(`scripts/body/body_rig.gd:912-919`, `cull_mode = CULL_DISABLED`, matte dark). At 32 verts
they are crude flat strips, and — like the eyes/teeth/tongue (#1) — they DO NOT follow the
skull morph, so on the neutral/feminine face they sit too high and detached, reading as
floating dark slashes above the brow ridge (`bvd_face_masc50.png`, `bvd_body_lit.png`).

**Eyes ARE a 96-vert proxy sphere pair (≈48/eye) driven by `assets/body/eye.gdshader`.** Two
causes compound:

(a) **Seating (#1)** — the eyeballs are displaced out of the sockets at neutral, which alone
makes them read as wrong.

(b) **The shader is keyed off the model-space NORMAL, not UVs** — `eye.gdshader:55-56`
(`v_model_normal = normalize(NORMAL)`) and `:60-65` (`theta = acos(dot(n, gaze_dir))`). The
iris/pupil cap is the set of fragments whose outward normal is within `iris_radius` of the
fixed `gaze_dir = +Z`. This **corrects** `body-render.md` finding #2, which claimed the iris
is computed "analytically from the proxy UVs" and collapses because the UVs are coarse — the
shader does not read UVs at all. The real low-tessellation problem is different: with ≈48
verts per eyeball the per-fragment interpolated normal is coarse, so the analytic concentric
rings (limbal ring `:91-93`, pupil ellipse `:96-101`) quantize into a faceted, blocky iris/
pupil rather than smooth circles. Additionally `gaze_dir` is a fixed model-space `+Z`
constant (`:22`); after the eyeball proxy is rotated/seated by the rig the geometric forward
may not equal model `+Z`, so the iris cap can sit off the visible front of the ball. Combined
with the wet low-roughness spec (`eye_roughness 0.06`, `:43`) over a near-flat low-vert ball,
the eye reads as a grey card with a small mis-centred dark blob (`bvd_eye_closeup.png`).

**Dominant cause: seating (#1) first, then low eyeball tessellation feeding the analytic
shader.** The eyebrow/eyelash badness is the same #1 follow failure plus the inherently crude
32-vert cards. **Confidence: high** for "what they are" and the shader mechanism (read +
rendered); **medium-high** that tessellation (not a UV bug) is the in-socket appearance
driver.

Renders: `/tmp/visual-check/bvd_eye_closeup.png`, `bvd_face_masc50.png`, `bvd_body_lit.png`.

---

## 3. Low-poly look — it is NORMALS/LIGHTING + a bare material, NOT tessellation

This **confirms the user's main hypothesis** and refutes the "raw tessellation" framing.

(a) **No normal map.** The skin material is a bare `StandardMaterial3D` with ONLY
`albedo_color` + `roughness` (`scripts/body/body_rig.gd:359-361`; consts `:72-73`). No
`normal_texture`/`normal_enabled`, no `albedo_texture`, no `roughness_texture`, no
detail-normal — grep clean across `body_rig.gd` and `body_converter.gd`. There is no
`.tres`/`.material` skin asset either.

(b) **Smooth-shaded, not flat/faceted.** Normals are area-weighted averaged per render vertex
(`tools/body_converter.gd:1118-1137`; identically rebaked under morph in
`scripts/body/body_state.gd:653-665`). The mesh is the full MakeHuman topology (13,380 base /
14,517 render verts per `body-render.md`). So the geometry is dense and smooth.

(c) **No tangents and no detail-normal support.** `body_converter.gd` writes
`ARRAY_VERTEX/NORMAL/TEX_UV/INDEX/BONES/WEIGHTS` only (`:267-275`) — **no `ARRAY_TANGENT`**.
So even if a normal map were assigned it could not be applied correctly without regenerating
tangents.

**Decisive test — flat ambient render (`bvd_body_ambient.png`):** with the directional light
off and ambient cranked, the body becomes a **uniform flat colour** — the leg seam, the
face/cranium two-tone, and all the "low-poly faceting" VANISH. That proves the perceived
low-poly/plastic look is a SHADING phenomenon (single directional light raking a normals-only,
map-less matte surface), not geometry density and not baked vertex colour (there is no
`ARRAY_COLOR` in the arrays). Under the lit render (`bvd_body_lit.png`) the same body reads
"low-poly/plastic" purely from the flat matte shading + the seam discontinuities below.

**Dominant visual problem: missing normal map + bare flat material (no albedo/roughness/AO
variation), NOT raw tessellation.** Hands/feet are the one place lower MH base density does
add genuine faceting. **Confidence: high.**

Renders: `/tmp/visual-check/bvd_body_ambient.png` (flat), `bvd_body_lit.png` (lit).

---

## 4. Shading seams (back-of-head centre, head→neck, inner legs) — ROOT CAUSE PINNED

**Root cause: hard one-sided normals at UV-island boundaries. The OBJ importer splits each
UV-seam corner into a separate render vertex, and `_compute_normals` accumulates face normals
PER RENDER VERTEX with no welding back to the base vertex — so the two sides of a seam get
different normals and never average across it, producing a sharp shading crease exactly along
each UV island edge.** This CONFIRMS the `body-render.md:81-83` suspicion (and the exact lines
it cited).

Mechanism, end to end:
- `tools/body_converter.gd:_parse_obj` creates one render vertex per unique `(v, vt)` corner
  (`:985,1010-1019`); a base vertex referenced under N distinct UVs (a UV seam) becomes N
  render vertices. The file's own comment notes base.obj has 21334 `vt` for 19158 `v` — i.e.
  it HAS seams (`:962-963`).
- `tools/body_converter.gd:_compute_normals` (`:1118-1137`) sums each triangle's face normal
  onto its three RENDER-vertex indices (`:1130-1132`) and normalizes per render vertex. A
  seam's two render-vertex copies each see only the triangles on their own side, so each gets
  a one-sided normal; they are never averaged together.
- The asymmetry that proves it is intentional-but-incomplete: SKIN WEIGHTS *are* welded across
  seams — they are copied from the base vertex via `render_to_base` (`:251-265`) so a split
  shares its parent's skinning. NORMALS get no such base-keyed accumulation. Skinning is
  seam-welded; normals are not. (The morph-time rebake `body_state.gd:657-662` repeats the
  identical per-render-vertex accumulation, so the seam persists under every morph.)
- This is NOT vertex colour/AO (no `ARRAY_COLOR`), NOT a normal-map/tangent seam (no normal
  map, no tangents — #3), and NOT a welding/coordinate bug in positions (the silhouette is
  continuous).

**Render proof:** `bvd_head_back.png` shows a crisp vertical shading discontinuity straight
down the centre-back of the skull — the MakeHuman scalp UV-island centre-back seam — with a
smooth silhouette (so it is shading, not geometry). `bvd_body_lit.png` shows the matching
seam down the inner/front line of the leg. **All of these disappear in `bvd_body_ambient.png`
(flat lighting)** — confirming a normal/lighting discontinuity, not baked-in colour.

The fix (not applied): accumulate face normals per BASE vertex (mirroring the
`render_to_base` weld already used for skinning at `:259-265`), then scatter the averaged base
normal back to each render vertex — so seam-split copies share one welded normal.

**Confidence: high** (code path + ambient-vanish test + direct seam render).

Render: `/tmp/visual-check/bvd_head_back.png`, `bvd_body_lit.png`, `bvd_body_ambient.png`.

---

## Render index (`/tmp/visual-check/`)

- `bvd_face_masc0.png` / `bvd_face_masc50.png` / `bvd_face_masc100.png` — frontal face,
  masculinity 0/50/100 (masc0==masc50 byte-identical: proxies don't follow gender).
- `bvd_face_neutralbase.png` — neutral with ProxyMorph bypassed (==masc50: morph delta ≈0).
- `bvd_face_hmin.png` / `bvd_face_hmax.png` — height 150/200 cm.
- `bvd_eye_closeup.png` — tight: shows teeth/tongue cards protruding by the nose, blocky eyes.
- `bvd_face_3q.png` — 3/4 face.
- `bvd_head_back.png` — back-of-head centre seam.
- `bvd_body_lit.png` — full body, single directional light (seams + plastic look visible).
- `bvd_body_ambient.png` — full body, FLAT ambient only (all seams + low-poly look vanish).

## Corrections to `body-render.md`

- #2 "iris computed analytically from the proxy UVs" — **wrong**: the eye shader keys off the
  model-space NORMAL (`eye.gdshader:55-65`), not UVs. The low-vert problem is normal-quantized
  faceting of the analytic rings, not a UV parameterization collapse.
- #2/#3 "eyes correctly seated, placement is correct" — holds only at the masculine end; at
  neutral/feminine the proxies are materially displaced (root cause #1 here).
- #3 face two-tone "cause unverified" — now pinned: same UV-seam one-sided-normal mechanism as
  #4 (vanishes under flat ambient).
