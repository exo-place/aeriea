# Creator + Body — design candidate: DIRECT-MANIPULATION-FIRST

Frame: **the body itself is the primary UI.** You grab and reshape it. Sliders and numeric
entry are demoted to a secondary, optional surface — never the path of first resort. The whole
creator is designed around making grab-and-pull excellent: discoverable, bounded, symmetric by
default, and correctly mapped to anatomy. This is a design artifact only — **no feature code.**

This candidate is one of N independent frames; it argues its own case and flags where it is
least sure. It is grounded in the verified diagnosis (`docs/artifacts/diagnosis/*`) and the
decided parameterization (`docs/decisions/body-parameterization.md`, esp. §9b Slice D, which
already ships a drag-to-modify core), and against the actual assets/engine state read on
2026-06-23.

---

## 0. Ground truth I verified before designing (corrects stale diagnosis)

Several diagnosis defects are **already fixed in the live code**; designing on top of the
diagnosis verbatim would re-propose solved problems. What I checked and found:

- **Shading seams — FIXED.** `tools/body_converter.gd:_compute_normals` (`:1159-1177+`) now
  accumulates face normals onto the **un-split BASE topology** (via `render_to_base`) and
  scatters one welded normal back to each UV-split render duplicate (commit `b12bcd7`,
  "CORRECT BY CONSTRUCTION"). This is exactly the fix `body-visual-reverify.md` §4 prescribed;
  it has landed. Seam creases at back-of-head / inner-leg should be gone. *Would re-verify with
  a flat-lit render before trusting fully — see quality bar.*
- **Tangents — PRESENT.** The converter computes `ARRAY_TANGENT` from UVs (Lengyel,
  `:219-224`, `_compute_tangents`). `body-visual-reverify.md` §3(c) said "no tangents"; that is
  stale. **A skin normal map can now be applied correctly** — the blocker that diagnosis named
  is removed.
- **Proxy follow at non-male — FIXED.** The proxy detail library now carries **188 macro
  targets, identical to the body's 188**, and `universal-female-young-averagemuscle-
  averageweight` is present in both (`grep` of `base_body_proxies_detail.index.json` vs
  `base_body_detail.index.json`). `body-visual-reverify.md` §1's "proxy library baked against a
  disjoint macro set, eyes only seat at male" is **stale** — the proxy library was rebuilt.
  Eyes/teeth/tongue/brows should now morph-follow gender/age. *Quality bar re-verifies this.*
- **Hair cap default — FIXED earlier.** Default no longer drapes the CC0 long-hair guide over
  the face (`body-render.md` §1) per the part-library default work.

**Still real (not fixed), and this design must address:**
- No skin **normal/roughness/albedo map** — bare `StandardMaterial3D` with albedo+roughness
  only (`body_rig.gd:359-361`). The dominant "plastic" look (`body-visual-reverify.md` §3a).
- **Eye shader is normal-keyed analytic over a ~48-vert/eye sphere** (`eye.gdshader:55-65`);
  rings quantize into facets at low tessellation (`body-visual-reverify.md` §2b).
- **Eyebrows/eyelashes are 32-vert authored dark cards** (`body-parameterization.md` §11.1),
  readable but crude, with a notch at the brow peak.
- **`breast/BreastSize` macro has NO driving path** — it is `kind:macro` with empty `targets`
  (`modifier_registry.json:248`), `_project_modifiers` `continue`s on macro kind
  (`body_state.gd:553`), and the `mincup/averagecup/maxcup` factor cube is **not imported**
  (only `cupidsbow` lip targets match "cup" in the detail index). The *working* size control is
  the bidirectional `breast/breast-volume-vert-down|up`, which IS in the library and IS the
  region slider "size" (`region_sliders.gd:42`). So "size is mislabeled / has no path" resolves
  to: the **macro** is dead, the **bidirectional volume axis** is live. Design §4 makes the
  semantics honest.
- **Unbounded additive stacking** — per-modifier values clamp to range, but composed
  displacement sums with no combined cap (`body-reverify.md` §2; `detail_library.gd:104`).
  Monstrous proportions are reachable. Design §3 fixes this.
- **Sculpt has no symmetry** — drag is per-vertex, one-sided; only the slider path mirrors
  (`body-reverify.md` §1). For a direct-manipulation-first creator this is the single biggest
  gap. Design §1 makes symmetry the default.
- **State lost on scene-switch/restart** — no `user://` persistence (`creator-ux.md` §7).
- **Default camera shows the BACK** (`creator-ux.md` §1). Trivial but on the critical path.
- **Pregnancy morph in base creation** — `stomach/stomach-pregnant-decr|incr` surfaced as the
  generic "belly" slider (`body-reverify.md` §3). Design §2 gates it.
- **VR: not implemented at all.** No `XR`/`OpenXR` references in `scripts/` (grep clean). VR is
  a design commitment (`units-and-scale.md`), not code. Design §6 specifies the story; I flag it
  as the least-grounded section.

---

## 1. The editing model — direct manipulation as the primary verb

The shipped Slice D (`body-parameterization.md` §9b) already has the hard parts: a CPU
raycast picker, a per-vertex→candidate-modifier accel structure, a **continuous locality
metric** that makes the most-local axis dominate a pull, zoom-adaptive sensitivity, and live
re-bake through the correct-normals path. This design **keeps that core** and builds the whole
creator around it, fixing what makes it feel like a secondary feature today.

### 1.1 Grab-and-pull is the default mode, not a mode behind `M`

**Decision:** there is no "sculpt mode toggle." The body is **always** grabbable. Camera and
sculpt disambiguate by **what the pointer hits and which button**, exactly as Slice D already
discriminates inside sculpt mode, just promoted to always-on:

- **Left-press ON the body (ray hits a triangle)** → grab + pull that region. This is the
  default, first-touch interaction.
- **Left-press on empty space (ray misses)** → orbit the camera.
- **Right-drag** → pan. **Scroll / pinch** → zoom. Always available.
- **Hover (no button) on the body** → live region glow showing the grab footprint (the
  `glow_weights` map already exists, `body-parameterization.md` §9b).

This kills `creator-ux.md` §2 entirely: there is no hidden mode keybind to forget, because
there is no mode. The "M to exit / press M" discoverability trap cannot exist. A persistent
one-line hint ("drag the body to reshape · drag empty space to rotate") sits under the
viewport; it never changes because the interaction never changes.

### 1.2 Two grab gestures, one primitive: **drag-sculpt** and **region-handle**

The locality math gives drag-sculpt for free. I add ONE complementary affordance — region
handles — because pure free-sculpt is hard to aim precisely and bad in VR at arm's length.

- **Drag-sculpt (free):** click anywhere on the surface and pull. The locality-weighted
  decomposition engages the most-local modifier family and reshapes (Slice D math). This is the
  exploratory, "I'll just push this in" gesture.
- **Region handles (snap targets):** a small set of **named grab anchors** float just off the
  surface at the canonical edit points — nipple, breast apex, hip point, glute apex, waist
  pinch, shoulder, jaw angle, chin, nose tip, brow, belly. Each handle is bound to a **specific
  modifier (or 1–2)**, not to whatever the locality metric guesses. Grabbing a handle is the
  *precise, repeatable, labeled* gesture; the handle shows its name + current value on grab
  ("breast height +0.32"). Handles are the bridge between "grab the body" and "I know exactly
  which control I'm moving." They are the primary VR affordance (§6) and the discoverability
  layer on flat (you can *see* what's editable).

Handles are **data**, not code: a table `[modifier_full_name, anchor_render_vertex_or_bone,
drag_axis_hint, label]`, parallel to `region_sliders.gd`'s data table. One handle definition
list, projected to both flat billboards and VR grab volumes (library-first / projection-from-
one-definition, CLAUDE.md). The existing `region_sliders.gd` GROUPS table is the seed source —
most handles map 1:1 to an existing region slider's modifier.

### 1.3 Symmetry: **default ON, mirror toggle, paint-asymmetry as an explicit opt-in**

This is the biggest sculpt fix. Today sculpt is one-sided and there is no symmetry concept in
the drag path (`body-reverify.md` §1).

**Decision:** sculpt mirrors across the body midline **by default**.

- The drag decomposition, after computing a `value_delta` for a candidate modifier, also
  applies the **mirror-partner modifier** the same delta. The partner is found structurally:
  bilateral modifiers are explicit `l-…`/`r-…` pairs in the registry (the slider path already
  exploits this — `region_sliders.gd:136-145` `resolve_full_names`), and midline modifiers
  (nose, chin, head-scale) are self-mirroring (no partner). So mirroring is "if the engaged
  modifier is `armslegs/l-upperarm-muscle-decr|incr`, also drive the `r-` twin by the same
  delta." No new geometry, no per-vertex mirror raycast — it reuses the registry's existing
  left/right structure, which is the clean primitive.
- A **Mirror toggle** (default ON) in the viewport corner. OFF = the side you grab moves alone.
- **Asymmetry is an explicit, opt-in act**, never the default and never accidental. Turning
  Mirror off and pulling one side is how you get a real, intended asymmetry (a sports injury
  scar, a stylized look). This satisfies "asymmetry is a *want*, not a default bug"
  (`creator-ux.md` §3) while still making it reachable — the diagnosis correctly noted there's
  currently *no way* to make sides differ via the named path.

### 1.4 The role left for sliders / numeric entry

Sliders are **not deleted** — they are demoted to a collapsible secondary panel, because some
things genuinely want a number, not a grab:

- **Headline axes that are not local surface motion** keep numeric entry: `age_years` (type
  "18"), `height_cm` (type "172"), `masculinity`, `muscle`, `weight`, `proportions`. You cannot
  meaningfully "grab" age or whole-body stature; these are global scalars. They live in an
  always-visible top strip in **natural units** ("Age: 25 years", "Height: 175 cm") per
  `body-parameterization.md` §7, with both a slider and a typeable field
  (fixes `creator-ux.md` "no numeric entry" want).
- **The full detail tail** (the 291-modifier registry minus the ~70 curated region/handle set)
  stays reachable through the categorized slider tree (`body-parameterization.md` §7,
  `*_sliders.json`), behind a "Fine controls" disclosure. It is the long-tail escape hatch, not
  the front door.
- **Every region handle has a paired numeric readout** so a grab can be dialed to an exact
  value after the gross gesture (grab to ~there, then nudge the number).

Net: **grab is the verb; numbers are the fallback and the precision finisher.** A new player
never has to find a slider to make a body. A power user can still type an exact height.

---

## 2. What is editable in base creation vs gated

**Rule (decided):** base character creation exposes **morphology that a body has at rest** —
the static shape of an adult (or chosen-age) human. It excludes **dynamic / state morphs** that
represent a transient physiological condition, because those belong to the *simulation* layer
(pregnancy progression, arousal, weight change over playtime), not to "who this character is."

Concretely:
- **In base creation:** all proportion/shape/size morphs — breast size & shape, glutes, hips,
  waist, torso, limbs, neck, full face/head shape, genital shape, muscle/fat distribution. These
  are anatomy and are NOT gated (`body-parameterization.md` §5: gate the verb×body intersection,
  never the morph primitive). NSFW-first: genital shape is editable; SFW is a render toggle.
- **Gated OUT of base creation (moved to the sim/transformation layer):**
  - **`stomach/stomach-pregnant-decr|incr`** — this is a *pregnancy-state* morph
    (`body-reverify.md` §3 confirmed it's the MakeHuman pregnant-belly target, currently
    mislabeled as the generic "belly" slider). **Decision:** remove it from the base belly
    control. Base creation gets a *body-fat belly* control instead — drive belly roundness from
    `weight` + `stomach/stomach-tone` (soft↔defined), which is the at-rest adiposity a character
    *has*. Pregnancy belly is driven by the sim's pregnancy system later, writing the same
    modifier at runtime. This keeps the morph in the engine (not crippled) but out of the
    "design your resting body" surface where it reads as a confusing always-on slider.
  - **Arousal / engorgement / expression-state morphs** (the `expression/` AU channels, any
    arousal-driven genital morph) — these are live-state, driven by `ExprState`/sim, not by the
    creator. Not in base creation.
- **The age gate is a predicate, not a removed control:** `age_years` is fully continuous
  (1–90, child morphs render for NPCs/family). The Layer-1 gate is `is_adult_body()` (`>= 18`)
  on the *verb* side (`body-parameterization.md` §5). The creator for a **player** character
  defaults age to 25 and, per DESIGN.md, the playable body is adult; child-range is for authored
  NPCs, not a player self-insert NSFW path. (This design does not change the gate; it inherits
  it.)

---

## 3. Bounds — preventing monstrous proportions

The defect (`body-reverify.md` §2): per-modifier values clamp, but the **summed displacement**
of overlapping regions is unbounded — bust + breast-volume + belly + waist + hips all push
neighboring verts and add with no combined cap, and at extremes the silhouette goes angular
(`body-reverify.md` §4). Direct manipulation makes this *worse* in principle (a determined pull
can keep going), so bounds are load-bearing here.

**Decision: a three-layer envelope, all data-driven, applied in the morph projection (not the
UI), so it bounds sculpt and sliders identically.**

1. **Per-modifier range clamp (exists, keep):** each value in `[-1,1]`/`[0,1]`
   (`body_state.gd:554,563`). Necessary, not sufficient.
2. **Per-region combined-displacement cap (new):** group co-located modifiers into **plausibility
   regions** (breast cluster, hip/waist cluster, belly cluster, each limb segment, face). For
   each region, cap the **L2 magnitude of the summed per-vertex displacement** at the region's
   busiest vertices to a region-specific ceiling `D_max_region` (in metres). Implemented as a
   post-sum scalar: after `bake_morphed_normals` composes the region's contribution, if the
   peak displacement exceeds `D_max_region`, scale that region's *contributing modifier deltas*
   down by the ratio. This is the principled fix for "five overlapping sliders stack to a lump"
   — it bounds the *result*, not the inputs, so no single slider has to be artificially short.
   The ceilings are **data** (a table keyed by region), tuned against renders, validated like
   the rest of the substrate (CLAUDE.md "validate against reality; tests are the spec").
3. **Global plausibility envelope (new, soft):** a whole-body check that the realized mesh stays
   within a gross AABB / volume band relative to stature (e.g. limb-circumference-to-height
   ratios within a wide human-plus-stylized range). This is a **soft** clamp with a visible
   "out of envelope" indicator rather than a hard wall, so deliberate stylization (Warframe-ish,
   the reference set) is reachable but accidental monstrosity is not the default. A "strict
   plausible" vs "stylized" creator preset selects the envelope width.

**Why post-sum scaling, not per-modifier shrinking:** the angular-silhouette artifact
(`body-reverify.md` §4) comes from base-mesh tessellation being unable to represent extreme
*displacement*, not from any one modifier. Capping the *composed* peak displacement directly
targets the cause; it also leaves moderate combinations untouched (the cap only bites at
extremes, where renders already show lumps). The tessellation itself is not increased (out of
scope — MakeHuman base density is fixed), so the envelope is the honest mitigation.

*Least sure:* the exact `D_max_region` values and whether per-region L2-peak is the right metric
vs a smoothness/curvature constraint. **Would tune against a render sweep** (the existing
`tools/age_sweep_render` pattern, extended to a proportion sweep) before committing numbers.

---

## 4. Correct breast-size semantics (and the macro-vs-axis honesty fix)

Verified state: `breast/BreastSize` is a dead macro (no targets, `_project_modifiers` skips it);
the live size control is the bidirectional `breast/breast-volume-vert-down|up`, already wired as
region slider "size" and present in the detail library.

**Decision:**
- **Retire the dead `BreastSize`/`BreastFirmness` macro entries from the creator surface
  entirely** (retire, don't deprecate — CLAUDE.md). They map to nothing; exposing them is a lie.
  Either import the `mincup/averagecup/maxcup` factor cube to make them real, **or** drop them.
  I choose **drop** for the creator: the bidirectional volume + shape axes give finer, more
  direct control than a 3-anchor cup macro, and the cup cube is 200+ extra targets for a coarser
  result. (If a "cup size" *readout* is wanted, compute it from the realized breast geometry, as
  MakeHuman computes cm/kg emergently — `body-parameterization.md` §1.4 — rather than driving a
  macro.)
- **Expose breast size as the primary handle "Breast size,"** bound to
  `breast/breast-volume-vert-down|up`, grabbable at the breast apex handle. Pulling the apex
  out/up increases volume; this is the direct-manipulation-native control and it is correctly
  labeled because the modifier genuinely is the volume axis. Secondary handles/sliders for
  projection (`breast-point`), spacing (`breast-dist`), height (`breast-trans`), nipple size/out
  — all already real bidirectional targets in the library (`region_sliders.gd:42-49`).
- **The bounds envelope (§3) governs the breast cluster** so size + projection + spacing don't
  stack into a non-anatomical result.

General principle this instantiates: **every control on the creator surface must drive real
target deltas present in the detail library.** A build-time assert (extend
`tests/body_region_sliders_test.gd`, which already verifies each slider's target is present with
nonzero deltas) should fail if any exposed handle/slider binds a modifier whose targets are
absent — so a dead control like `BreastSize` can never silently ship again.

---

## 5. Visual fidelity — the hard part, grounded in the asset reality

Goal: eyes, eyebrows, and skin that read as genuinely good, given MakeHuman CC0 base
(~14.5k render verts), Godot 4.6, no existing maps, low-vert proxies. For each: the technique,
whether it's achievable with what we have, and what I verified vs would check.

### 5.1 Skin — normal + roughness + subtle albedo variation map

**This is the dominant lever** (`body-visual-reverify.md` §3a: bare matte material is the whole
"plastic" look). And the prior blocker is gone: **tangents now exist** (`ARRAY_TANGENT`,
verified §0), so a tangent-space normal map applies correctly.

**Technique (decided):**
- Add a **detail normal map** + **roughness map** + slight **albedo break-up / AO** to
  `_skin_material` (`body_rig.gd:359-361`), keyed off the existing MakeHuman body UVs
  (the mesh already has `TEX_UV`; `body_converter.gd` writes `ARRAY_TEX_UV`).
- **Source of the maps — CC0, verifiable provenance:**
  - **Detail/pore normal:** a **tiling CC0 skin micro-detail normal** (pores/fine wrinkle),
    applied as Godot's `detail_normal` or a high-frequency tiled `normal_texture` over a low
    UV-scale, so it doesn't need to be a bespoke per-UV-island bake. CC0 skin micro-normal
    textures are available from CC0 texture libraries (e.g. ambientCG / Poly Haven skin/leather-
    grain class) — *provenance must be pinned and CC0-verified per asset*, same discipline as the
    MakeHuman pin (`body-parameterization.md` §6). A tiling detail map is the cheapest big win:
    it breaks the flat shading everywhere without authoring a 4k body bake.
  - **Roughness:** a tiling CC0 roughness/cavity that adds the wet/dry variation (oilier
    forehead/nose, drier cheeks) — even a low-contrast tiling map removes the uniform-plastic
    read. Achievable now.
  - **Albedo break-up + AO:** subtle. Either a tiling subdermal mottling at low strength, or a
    one-time **baked AO** over the MakeHuman UVs (cavity in nostril creases, under chin, finger
    gaps) generated offline (xatlas/Blender bake of the base mesh) and committed as a CC0-by-our-
    authorship asset. AO bake is the one bespoke step; it is one mesh, done once, deterministic.
- **Subsurface:** enable Godot's `subsurf_scatter` on the skin material at a low strength
  (`StandardMaterial3D` supports SSS in 4.x). Skin without SSS reads waxy; with even modest SSS
  it warms up at grazing angles. Achievable now, one flag + strength.
- **Achievability:** **high for the tiling detail-normal + roughness + SSS** (engine-native,
  tangents present, UVs present — all verified). **Medium for the AO bake** (needs an offline
  Blender/xatlas step in the asset pipeline; one-time, deterministic, fits the `nix build
  .#body-assets` derivation). **Provenance is the open item:** I have NOT pinned a specific CC0
  skin texture; *would verify license + commit the exact source hash* before use.

*Would check:* render the body with just the tiling detail-normal + SSS, no other change, under
the real Vulkan path (not llvmpipe), to confirm the plastic read breaks — this single change is
likely 70% of the perceived fix per `body-visual-reverify.md` §3.

### 5.2 Eyes — denser proxy sphere + keep the (good) analytic shader, fix gaze + cornea

The shader is actually good design — resolution-independent, fully parameterized, NSFW/SFW-
agnostic, slit-pupil capable (`eye.gdshader`). The problems are **geometry tessellation** and
**gaze-axis correctness**, not the shader concept (`body-visual-reverify.md` §2 corrects the
earlier "UV collapse" theory — it's normal-quantization on ~48 verts/eye).

**Technique (decided):**
1. **Denser eyeball proxy.** Replace the 96-vert (both eyes) low-poly sphere with a higher-res
   UV sphere (target ~**500–800 verts/eye**), so the per-fragment interpolated model-space
   normal is smooth and the analytic iris/pupil/limbal rings stop faceting. A clean UV sphere is
   trivial to generate procedurally at build time (no external asset, fully CC0-by-authorship) —
   the proxy build pipeline (`tools/body_proxy_build.gd`) already authors geometry
   (`_build_authored_face_hair`), so authoring a denser eye sphere fits. It must keep the
   single-index `.mhclo` attachment to the eye-helper base verts (14598..14742,
   `body-parameterization.md` §11) so it stays seated + rigged + morph-following.
2. **Fix the gaze axis.** `gaze_dir` is a fixed model-space `+Z` constant (`eye.gdshader:22`);
   after the rig seats/rotates the eyeball the geometric forward may differ, putting the iris
   off-front (`body-visual-reverify.md` §2b). **Decision:** drive `gaze_dir` per-eye from the
   actual eye-bone forward axis at bind time (the rig knows `eye.L`/`eye.R` orientation,
   `body-render.md` "PIPELINE OK"), set as a per-surface shader param. This also unlocks **eye
   contact / look-at** later (sim drives gaze), which the immersion goal wants.
3. **Cornea/refraction:** keep the wet low-roughness spec; optionally add a thin **clear-coat**
   (Godot `clearcoat` on the eye material) for the corneal glint, and a slight outward bulge of
   the corneal cap in the denser mesh so the highlight reads as a dome, not a flat disk. A true
   refraction (parallax iris under a cornea) is possible via a small height-offset in the shader
   (raymarch the iris plane below the surface along the view vector) — **achievable but
   deferred**; the denser mesh + clearcoat gets most of the way.
- **Achievability:** **high** for denser proxy (procedural, build-time) + gaze-from-bone +
  clearcoat — all use existing pipeline + engine features I verified present. Parallax-refraction
  iris is **medium** (shader work) and deferred.

*Would check:* the assumption that ~500–800 verts/eye removes the faceting (vs needing more) —
render a single eye in isolation at a few resolutions and inspect the iris ring smoothness, the
exact probe `body-render.md` §2 recommended.

### 5.3 Eyebrows + eyelashes — alpha-textured hair-card strips, replacing the 32-vert solid cards

Current: 32-vert opaque dark cards, authored in-repo, morph-following but crude with a peak
notch (`body-parameterization.md` §11.1). They're 2-sided solid keratin, which reads as a flat
slash.

**Technique (decided):**
- **Keep the authored, morph-following card geometry approach** (it's CC0-clean and rigs
  correctly via nearest-vert bind to the eye-helper base verts — the hard part is solved). But:
  1. **Make them alpha-textured hair cards, not solid.** Apply a **CC0 brow/lash alpha strip
     texture** (a few overlapping hair strands per card) with `transparency = ALPHA_SCISSOR` (or
     alpha-hash) so the silhouette is feathered strands, not a solid block. This is the standard
     game brow technique and is exactly what the project doc noted the base.obj lash cards *want*
     ("sparse alpha-texture cards … without their lash texture they render as opaque pale
     sheets" — `body-parameterization.md` §11.1). The fix is to **author/source the alpha
     texture** the cards were designed for.
  2. **Add a few more strips + fix the peak notch.** Bump from one ribbon to ~3–5 layered
     thinner strips per brow following the brow ridge, eliminating the single-card self-occlusion
     notch by overlapping cards instead of one bent ribbon. Still tiny vert count; still authored
     at build time; still nearest-vert bound.
  3. **Brow color** ties to a hair-color parameter (so brows match chosen hair).
- **Source of the alpha texture:** a small hand-authored CC0 hair-strand alpha (a strip of
  tapered strokes) — authorable in-repo (a few hundred px, CC0-by-authorship, no external
  dependency, no license risk). This is the same "author it rather than vendor non-CC0 community
  assets" stance the project already took for the geometry.
- **Achievability:** **high.** Alpha-scissor transparency, `cull_disabled` 2-sided cards, and
  per-surface texture are all engine-native and already used; the only new asset is a small CC0
  alpha strip we author. No tangent/normal blocker (brows don't need a normal map).

*Least sure:* whether alpha-scissor (hard edges, no sorting issues, VR-safe) looks good enough
vs alpha-blend (softer but needs depth sorting, flickers in VR). **Would prototype both** and
pick per the VR-safety constraint — alpha-scissor is my default bet because it sorts correctly,
which matters for the VR-first goal.

---

## 6. Camera / UX, persistence, and the VR story

### 6.1 Camera + UX

- **Default view shows the FRONT** (face + chest), fixing `creator-ux.md` §1. The diagnosis
  found the `_yaw=PI` default renders the back and that the in-code comments contradict the
  render; **decision:** set the default yaw to whatever a verified render confirms shows the
  face (likely `_yaw=0` per the body-faces-`-Z` convention in `interpreted_player.gd:186`), and
  **verify with a render**, not blind (the diagnosis explicitly warns the math+render already
  disagree). First thing the player sees is the face.
- **Always-on grab** (§1.1) removes the mode badge problem.
- **One Theme resource** with a small type scale (title/body/caption), applied to the
  CanvasLayer, deleting the 13 ad-hoc per-widget font overrides (`creator-ux.md` §6). Spelled-
  out labels ("bust circumference," not "bust circ." — `creator-ux.md` §5).
- **Async load + loading indicator** instead of the synchronous `_ready` freeze
  (`creator-ux.md` §8): defer the heavy builders (accel structure, picker grid — both pure/
  deterministic) off the first frame; the picker grid is already lazy-rebuildable.
- **Export collapses** to {JSON | image} toggle + "include history" checkbox + one Export
  button + a visible save path (`creator-ux.md` secondary observations).

### 6.2 State persistence

`creator-ux.md` §7: state is lost on scene-switch and restart (no `user://` IO).

**Decision:** autosave the `BodyState` (and the `HistoryTree`) to `user://creator/autosave.*`
**on every committed change and on `_exit_tree` / `WM_CLOSE_REQUEST`**, restore on `_ready`.
The serialization already exists write-side (`CreatorIO.history_to_json`,
`embed_history_in_image`, `creator_io.gd`); the missing piece is the **read-back/import path**
in `character_creator.gd` (the diagnosis confirmed export is write-only with no import). Add a
real **Import** action too. Because `BodyState` is a sparse serializable struct
(`body-parameterization.md` §3, sorted-key deterministic), the save is tiny and diffs cleanly —
this also makes characters shareable as files (the self-hosted-multiplayer ethos).

### 6.3 VR — direct manipulation is *more* native in VR than on flat (the strongest case for this frame)

This is the section I am **least confident** about because **no XR code exists yet** (grep
clean). The design is sound but unvalidated against a running headset.

**Decision / story:**
- **Region handles (§1.2) are the primary VR affordance.** In VR you reach out and physically
  grab a floating handle (nipple, hip, jaw, brow) with the controller/hand and move it in 3D
  space; the bound modifier follows the controller displacement projected onto the handle's
  drag-axis hint. This is the most immersive possible body-editing gesture and is *exactly* what
  the direct-manipulation frame is built for — the body is literally the UI, no panels floating
  in space. VRChat-style live grab (reference set) is the model.
- **Free drag-sculpt in VR:** grab any surface point with the controller and pull; reuse the
  same locality decomposition, but driven by **controller world-space delta projected onto the
  surface-tangent screen-equivalent** rather than a mouse pixel delta. The Slice D math is
  already a 2D-screen-frame computation (`body-parameterization.md` §9b) — for VR it generalizes
  to "project the controller motion into the view plane at the grab depth," which is the same
  shape of math. *Would need to re-derive/verify the VR projection; flagged.*
- **Symmetry (§1.3) is even more valuable in VR** — you grab one breast/hip and both move,
  halving the reach work.
- **Scale/comfort:** edit at a comfortable arm's length with a scale grip (two-controller
  pinch to scale the body up/down for detail vs gross work), standard VR sculpt UX.
- **Numeric/slider fallback** appears as a wrist-anchored or world-locked panel only when summoned
  — never the default, consistent with the frame.
- **Cross-platform parity:** the **handle definition table is the single source**; flat renders
  handles as billboard gizmos with mouse-drag, VR renders them as grab volumes with controller-
  grab. Same data, two projections (CLAUDE.md). The locality-sculpt core is shared; only the
  input→drag-vector adapter differs per platform.

**Honest gap:** I verified there is **zero** XR integration in the codebase. The VR story is a
design specification grounded in the *existing sculpt math being projection-friendly* and the
*reference-set precedent*, NOT in a tested headset build. The first VR milestone must be a
spike: a single grabbable handle moving one modifier on a Quest build, to validate the
controller-delta→value mapping and comfort before building the full handle set.

---

## 7. Concrete, testable quality bar

"Good" = measurable. The creator+body ships when:

**Visual (verified by render under the real Vulkan path, not llvmpipe):**
1. **Skin does not read as plastic.** A side-by-side of the lit body before/after the skin
   material work shows broken-up specular/roughness; no uniform-matte appearance. *Test:* a
   committed render check + a human eyeball pass; the flat-ambient render (`body-visual-
   reverify.md` method) and the lit render should differ in *micro-detail*, not just in big
   shadows.
2. **No shading seams.** Back-of-head, head→neck, inner-leg seams absent in a single-directional-
   light render (the §0 fix should already deliver this — **re-verify it actually does** with
   `tools/normal_seam_render`).
3. **Eyes read as eyes at conversational distance.** Iris/pupil/limbal rings are smooth circles
   (no facets) in a face close-up; the iris is centered on the visible front of each eye at
   neutral gaze; both eyes match. *Test:* the isolated-eye render probe + a face 3/4 render.
4. **Eyebrows read as feathered hair, not solid slashes**, and sit on the brow ridge (follow the
   morph) across masc 0/50/100 and age child/adult/old. *Test:* the gender×age render matrix
   (`body-visual-reverify.md` already has this harness pattern).
5. **Proxies (eyes/teeth/tongue) seated correctly at ALL gender/age values** — re-verify the §0
   fix with the coverage-dump + render-matrix method from `body-visual-reverify.md` §1 (the
   byte-identical-render test that exposed the original bug becomes the regression guard).

**Interaction (verified by test + headless drag harness):**
6. **First-touch grab works with zero instruction:** a player can grab and reshape the body
   without finding a slider or a mode key (no mode exists). *Test:* the always-on grab path; an
   up-drag at the breast apex increases volume, at the nose engages the nose family (extend
   `tests/morph_drag_test.gd`).
7. **Symmetry default holds:** a one-sided arm/leg drag moves both sides by default; toggling
   Mirror off moves one. *Test:* assert the `r-` twin receives the same delta when Mirror on,
   none when off.
8. **No control is a lie:** the build-time assert (extend `body_region_sliders_test.gd`) fails
   if any exposed handle/slider binds a modifier whose targets are absent from the detail
   library (catches the dead-`BreastSize` class of bug).
9. **Bounds hold:** the "all overlapping region morphs at max" configuration produces a body
   within the plausibility envelope (no angular lumps beyond the cap). *Test:* extend the
   proportion sweep render; assert peak per-region displacement ≤ `D_max_region`.
10. **Pregnancy/state morphs are absent from base creation** (gate assert): the belly control in
    base creation does not bind `stomach-pregnant`. *Test:* assert the creator handle/slider set
    excludes the listed state morphs.

**UX / robustness:**
11. **State survives** scene-switch and app restart (autosave round-trips byte-identical via
    `user://`). *Test:* save→quit→reload golden.
12. **Default view shows the face** (verified render).
13. **Open is not a hard freeze:** a loading indicator appears within one frame; heavy builders
    are deferred/threaded. *Test:* the existing timing harness, plus "indicator visible before
    builders complete."
14. **`nix run .#test` stays green** (all suites print their RESULTS line — the anti-truncation
    guard, CLAUDE.md Tests).

**VR (milestone gate, not v1 ship gate):**
15. A Quest build can grab one region handle and move one modifier with a comfortable
    controller-delta→value mapping (the spike). Full handle parity follows the spike's verdict.

---

## 8. Decided-calls summary

| area | decision |
|---|---|
| editing model | always-on grab (no mode toggle); drag-sculpt + named region handles; both are data |
| symmetry | mirror **default ON**; asymmetry is explicit opt-in via Mirror-off; reuses registry `l-/r-` pairs |
| sliders/numbers | demoted to secondary; kept for global scalars (age/height/etc.) + long-tail + precision finish |
| gated from base | pregnancy/state/arousal morphs → sim layer; shape/size morphs all in (NSFW-first, ungated) |
| bounds | per-modifier clamp + per-region composed-displacement cap + soft global envelope (strict/stylized presets) |
| breast size | retire dead `BreastSize` macro; size = bidirectional `breast-volume-vert-up` handle (real, in library) |
| skin fidelity | tiling CC0 detail-normal + roughness + SSS (+ one-time AO bake); tangents already present |
| eye fidelity | denser procedural eye sphere (~500–800 v/eye) + gaze-from-bone + clearcoat; keep analytic shader |
| brow/lash fidelity | alpha-textured CC0 hair-card strips (author the alpha) + more layered strips; keep rigged binding |
| persistence | autosave BodyState+history to `user://` on change/exit; add Import; restore on ready |
| VR | region handles as primary grab affordance; one handle table → flat gizmos + VR grab volumes |
| quality bar | the 15 measurable checks in §7 |

## 9. Where I am least sure (called out honestly)

1. **VR (§6.3).** Zero XR code exists in the repo (verified). The VR story is grounded in the
   sculpt math being projection-friendly and reference-set precedent, **not** a tested headset
   build. The controller-delta→value mapping and comfort are unvalidated; first VR work must be a
   spike, not the full handle set.
2. **Skin texture provenance + the AO bake (§5.1).** I have NOT pinned a specific CC0 skin
   normal/roughness source — would verify license and commit the exact hash. The AO bake adds a
   one-time offline Blender/xatlas step to the asset pipeline; achievable but not yet wired into
   `nix build .#body-assets`. The *engine-side* claim (tangents present, SSS available, UVs
   present) IS verified.
3. **Bounds tuning (§3).** The per-region `D_max_region` values and whether L2-peak-displacement
   is the right metric (vs a curvature/smoothness constraint) are unverified — would tune against
   a proportion-sweep render before committing numbers. The *mechanism* (post-sum scaling bounds
   the result not the inputs) is sound; the constants are not yet earned.

Secondary uncertainty: whether ~500–800 verts/eye fully removes iris faceting (would probe), and
alpha-scissor vs alpha-blend for brows/lashes (would prototype both, defaulting to scissor for
VR sorting safety).
