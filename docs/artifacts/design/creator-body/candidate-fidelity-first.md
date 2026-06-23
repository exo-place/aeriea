# Candidate design — Character Creator + Body, FIDELITY-FIRST frame

**Frame.** Start from "what makes the character actually look genuinely good," design
the rendering/asset pipeline to deliver that, and shape the editing system around what
the pipeline can faithfully support. The visual result is the primary constraint; the
controls serve it. This frame deliberately goes deepest on the visual-quality problem.

**Status:** design candidate (one of N for design-it-twice synthesis). No feature code.

> **Verification markers.** `[V]` = checked against the repo source/assets or the
> nix-pinned MakeHuman v1.3.0 tree (store path
> `/nix/store/f17xilfqj8v2xphny6qfy4xvp8pzg4mi-source/makehuman`, realized from the
> `body-assets.nix` pin) during this pass. `[U]` = unverified, with the check named.
> `[D]` = a design call (mine to make in this frame).

---

## 0. Ground truth I actually verified (corrects two stale diagnosis findings)

The diagnosis artifacts (`body-render.md`, `body-visual-reverify.md`) are mostly
accurate, but **two load-bearing claims are now STALE** — fixed in commits after those
docs were written. I re-checked the live source:

- **Tangents now exist.** `tools/body_converter.gd:281` writes `ARRAY_TANGENT`,
  computed Lengyel from UVs at `:224` (`_compute_tangents`); blendshapes carry a
  zero-tangent delta (`:408`) so morphs stay valid. Commit `b12bcd7` "fix(body): weld
  normals across UV seams + add tangents". `[V]` — **body-visual-reverify §3c "no
  ARRAY_TANGENT" is obsolete.** Consequence: **the mesh is normal-map-ready today.**
- **Seam normals now welded.** `_compute_normals` accumulates on the un-split base
  topology via `render_to_base` and scatters to UV-split duplicates
  (`body_converter.gd:215-218`; commit `5c33ca5`). `[V]` — **body-visual-reverify §4
  (one-sided seam normals) and body-render.md #3 (two-tone face) are fixed at the
  source;** any residual seam is now a *normal-map seam* problem (tangent discontinuity
  at UV islands), not a vertex-normal one.

These two corrections are why this frame is viable: a normal map + detail map is a
*drop-in* on the current arrays, not a pipeline rebuild.

What is still true and load-bearing `[V]`:
- Skin = bare `StandardMaterial3D`, `albedo_color`(0.86,0.68,0.58) + `roughness`0.7
  only — no normal/ORM/AO/SSS, no texture asset of any kind (`body_rig.gd:359-361`,
  `:72-73`). Reads matte-plastic; **this is the #1 fidelity defect** per the flat-ambient
  test (body-visual-reverify §3: low-poly look is *shading*, not tessellation).
- Eyes = 96-vert proxy sphere pair (~48/eye), `eye.gdshader` is fully **procedural,
  normal-driven** (not UV — corrects body-render #2), faceted at low vert count
  (body-visual-reverify §2b).
- Eyebrows/eyelashes = project-authored 32-vert proxy *mesh* cards, matte dark, two-sided
  (`body_rig.gd:912-919`). Crude flat strips.
- Mesh = 13,380 base / **14,517 render verts** `[V]`, full MH topology, single UV atlas
  (base.obj 21,334 vt / 19,158 v, 172 `usemtl`/`o`/`g` groups but one continuous mesh).
- Proxies (eyes/teeth/tongue/brows) don't follow the gender macro — baked against the
  wrong target set (body-visual-reverify §1). **This is a data-rebuild bug, prerequisite
  to ANY eye/brow fidelity work** — a beautiful eye seated in the wrong socket still looks
  broken. Folded into the plan as Gate 0.

### What MakeHuman v1.3.0 ACTUALLY ships for skin/eyes (I looked) `[V]`

This is the decisive asset-availability finding the frame demands:

- **NO skin albedo, normal, bump, roughness, or detail texture anywhere in the tree.**
  `find … -iname '*.png'` over the whole pinned source → 345 PNGs, ALL of them UI icons,
  theme art, or **litsphere matcaps**. The skin material `data/skins/default.mhmat` `[V]`
  references **no texture file**: it sets `shaderConfig bump true` / `normal false` but
  there is no `bumpmapTexture`/`normalmapTexture`/`diffuseTexture` line — it renders via
  a **litsphere matcap** (`skinmat_caucasian.png` 256², `_asian`, `_african`) plus
  procedural `autoBlendSkin` and `sssEnabled true` (an MH-shader feature, NOT a texture).
  **Verdict: MakeHuman gives us ZERO usable PBR skin maps.** A litsphere matcap is a
  baked-lighting hack, useless in a real PBR + dynamic-light + VR scene. We must
  source/generate every skin map ourselves.
- **Eyes DO ship a real asset:** `data/eyes/materials/brown_eye.png`, **1024×1024 RGBA,
  CC0** `[V]` — a genuine iris+sclera albedo for the MH low-poly eye UV
  (`data/eyes/low-poly/`, also vendored at `vendor/makehuman-cc0/data/eyes/low-poly/`).
  This is a better eye source than our current pure-procedural shader for the iris detail,
  and it's already in the licensed tree.
- **NO eyebrow/eyelash alpha-card textures** in the CC0 core (the brows are geometry).
  Eyebrow strips/alpha textures live in the MH **community assets** which are **not
  uniformly CC0** (body-parameterization §1.1 caveat) — out of bounds for vendoring.

---

## 1. THE VISUAL FIDELITY PLAN (the centerpiece)

Design rule for this frame: **every map is either (a) generated deterministically at
build time by an in-repo tool from a cited source, or (b) authored once and vendored
CC0.** No runtime LLM, no per-config baking, nothing that breaks the seeded-sim
invariant. Maps are static assets shared across all morphs (see §2 for why that holds).

### 1.1 Skin — the dominant defect, attacked in three tiers

**Tier A — detail-normal (microstructure), procedural, ships FIRST. `[D]`**
The single biggest perceived-quality jump for the least asset cost. A **tiling
detail-normal map** (skin pores + fine wrinkle grain) applied via
`StandardMaterial3D.detail_enabled` + `detail_normal` (Godot 4.6 BaseMaterial3D supports
a second detail UV/normal blend `[V]` API). Source: **generate it** — there is no CC0
skin pore map in MH. Two honest options:
  - Procedurally synthesize a seamless pore/grain normal from layered Worley+value noise
    in an in-repo build tool (`tools/skin_detail_build.gd`), deterministic, ~1024² tiling,
    committed as a `.png`. Cost: a few hours of tuning, zero license risk. `[D] preferred.`
  - OR vendor a CC0 skin micro-normal from a public CC0 library (e.g. Poly Haven skin
    detail textures are **CC0** — *would verify the exact file license at fetch time*
    `[U]`). Fallback if procedural grain looks synthetic.
This map is **morph-invariant** (it tiles in detail-UV space, independent of the macro
shape), so it survives every morph and every drag for free.

**Tier B — base normal + ORM, from a high-detail bake. `[D]`**
The MH base mesh has no sculpted high-frequency surface (no shipped normal map `[V]`),
so a meso-scale normal (nasolabial folds, lip creases, knuckles, collarbone hollow) must
be **baked from a higher-detail source**. The viable, deterministic, license-clean path:
  1. Run **Catmull-Clark subdivision** (1 level → ~58k verts, 2 → ~232k) on the CC0 base
     mesh in the build tool, optionally with a thin procedural displacement (pores/creases
     from the same noise basis as Tier A), as a *bake-only* high-poly. `[D]`
  2. **Bake** its surface detail to a tangent-space **normal map** + an **AO map** against
     the 14,517-vert low-poly's UVs (the single MH atlas — UVs already shipped). Godot has
     no offline baker, so the bake runs in **Blender headless** (already a reproducible nix
     tool pattern; `bpy` baking is standard) OR in an xrt-style GPU bake pass. `[D]`
     *Honest unknown:* whether to add Blender to the build graph vs. an in-Godot GPU bake —
     **would prototype both; flagged §6.**
  3. Emit a packed **ORM** (R=AO, G=roughness, B=metallic=0) so roughness varies (oily
     T-zone vs. matte cheek) — the flat 0.7 roughness is half the plastic look.
  Output: `skin_normal.png`, `skin_orm.png`, both morph-invariant in UV space, committed.

**Tier C — subsurface scattering (SSS). `[D]`**
Godot 4.6 Forward+ `StandardMaterial3D` exposes `subsurf_scatter_enabled` +
`subsurf_scatter_strength` + transmittance `[V]` (BaseMaterial3D API). Turn it on at a
**moderate strength (~0.15–0.25)** with a warm transmittance tint — this is what removes
the last of the "plastic" read on ears/nose/fingers under backlight. **Cost: Quest.**
Godot's SSS is a screen-space Forward+ effect; on the **Quest mobile renderer (Mobile/
Compatibility backend) SSS is reduced/absent** `[U] — would verify SSS availability on the
Mobile backend in 4.6`. **Decision:** SSS is a **Forward+ (PCVR/flat-desktop) feature,
gated off on Quest** via the LOD/quality tier (§2.3); Quest falls back to Tier A+B only.
This is an explicit, honest cross-platform split, not a regression.

**Skin albedo.** Keep the procedural `autoBlendSkin`-style tone (a tinted base color, not
a photo texture) — there is no CC0 full-body skin albedo in MH `[V]`, and a single baked
albedo would fight the customizable skin-tone slider. So albedo stays a **tunable color**
(extend the existing `SKIN_ALBEDO` to a creator-exposed tone + a subtle baked AO/redness
variation from the ORM). A full albedo *texture* is a later want, deferred.

**Achievability:** A (procedural detail-normal) — **high, ships first, no new dep.**
B (baked normal/ORM) — **high but needs an offline baker** (Blender-headless or GPU bake;
the mesh is already tangent+UV ready, the only blocker the diagnosis flagged is gone).
C (SSS) — **high on Forward+, off on Quest**, one API toggle, the cost is the platform
split, not the implementation.

### 1.2 Eyes — denser proxy + the shipped CC0 iris, hybrid shader `[D]`

Three coupled moves:
1. **Seat them first (Gate 0).** Rebuild the proxy detail library against the body's
   *actual* emitted macro target set so eyes follow the gender/age morph
   (body-visual-reverify §1). Non-negotiable prerequisite.
2. **Raise eyeball resolution.** 48 verts/eye faceting quantizes the analytic iris rings
   (body-visual-reverify §2b). **Target ~320–512 verts/eye** (a UV-sphere at ~16×16 or a
   subdivided icosphere) — cheap (a few hundred tris × 2), and removes the faceting that
   makes the procedural rings blocky. The MH `low-poly.obj` eye is the topology source;
   subdivide it in the build tool. `[D]`
3. **Hybrid iris: sample the CC0 `brown_eye.png` (1024² `[V]`) for iris/sclera detail,
   keep the procedural shader for the cornea/refraction.** The current `eye.gdshader` is
   fully procedural; the iris fibre noise reads synthetic up close. Decision: **add an
   iris albedo texture path** (sample the CC0 iris by the gaze-relative tangent-plane
   coords the shader already computes at `eye.gdshader:67-72`), tinted by an
   eye-color slider, and **add a parallax/refraction cornea**: offset the iris sample
   along the view ray by a small depth (the classic "iris-behind-cornea" parallax POM
   trick) so the iris sits *under* a clear convex cornea and shifts with view angle. This
   is the single technique that separates a good eye from a flat decal. Keep the wet spec
   (`eye_roughness 0.06`). `[D]`
   *Achievability:* high — parallax-iris is a well-trodden shader pattern, all inputs
   (gaze axis, tangent plane, view dir) already exist in the shader; the CC0 texture is
   in-tree. The faceting fix is just a denser proxy bake.

### 1.3 Eyebrows — keep mesh cards, fix follow + shade them as hair-cards `[D]`

The brows are 32-vert mesh cards `[V]` and there is **no CC0 alpha-card brow texture**
available (community assets aren't CC0). So:
  - **Don't switch to alpha textures** (no licensed source; alpha cards also need
    sorted-transparency which is a Quest cost). **Keep them as mesh**, but:
  - **Fix the follow** (Gate 0 — same root cause as eyes).
  - **Add a short alpha-gradient + anisotropic-ish dark keratin material** so the card
    edge feathers instead of reading as a hard slab; and **subdivide the strip** modestly
    (32 → ~96 verts) so it curves with the brow ridge.
  - **Stretch goal (deferred):** generate strand cards procedurally (a few dozen tapered
    quads following the brow-ridge curve) — better, but it's authoring work; the feathered
    mesh card is the shippable baseline. `[D]`
  Eyelashes: same treatment (feathered alpha on the existing 32-vert card).

### 1.4 Mesh resolution — normal-map the existing mesh; do NOT runtime-subdivide. `[D]`

The decisive evidence: the **flat-ambient render proves the "low-poly look" is shading,
not density** (body-visual-reverify §3). At 14,517 render verts the *silhouette* is smooth
except (a) hands/feet (genuinely lower MH density) and (b) extreme stacked morphs
(body-reverify §4, a bounds problem — §3 here). So:
  - **No runtime Catmull-Clark.** Runtime subdivision on a per-instance skinned,
    per-frame-CPU-morphed mesh (the `apply_morph_cpu` path) would multiply the morph-bake
    cost 4×/16× **every drag and every frame a body morphs** — unaffordable, and on Quest
    catastrophic. The morph pipeline (`body_state.bake_morphed_normals`) is the hot path;
    keeping vert count fixed keeps it cheap. `[D]`
  - **Subdivide ONLY at bake time** for the normal-map source (§1.1 Tier B) — the high
    detail lands in a *texture*, which is free to sample on Quest. This is the whole point
    of normal mapping: detail without geometry cost. `[D]`
  - **Hands/feet:** the one place density genuinely shows. Decision: **bake their meso
    detail extra-hard into the normal map** (knuckle/nail creases), and **defer** a
    targeted local subdivision of the extremity surfaces to a later want — not worth a
    topology change now. `[D]`

**Net:** the fidelity gain comes from **maps on the existing tangent-ready mesh + SSS +
better eyes**, not from more triangles. This is exactly the Quest-affordable choice.

---

## 2. How the rendering choices SHAPE / LIMIT the editing system

The fidelity plan constrains the morph/creator system in concrete ways:

- **Maps must stay morph-valid.** All skin maps are **UV-space, morph-invariant** by
  construction (detail-normal tiles in detail-UV; baked normal/ORM/AO are in the fixed MH
  atlas the morph never re-UVs). So **any morph or drag is automatically map-valid** — the
  morph moves vertex positions and recomputes vertex normals, and the tangent-space normal
  map rides on top. **This is the key enabling property** and it's why normal-mapping (not
  per-config baking) is the right seam: the creator can morph freely without invalidating
  fidelity. The *only* validity requirement on the morph pipeline: **it must keep
  recomputing tangents under morph** (currently blendshapes carry a zero-tangent delta,
  `body_converter.gd:408`, and the CPU rebake recomputes normals but **must also rebake
  tangents** or the normal map shears under large morphs — `[U] verify: does
  body_state.bake_morphed_normals rebake ARRAY_TANGENT? If not, that's a required add.`).
- **Morph bounds protect the bake.** The baked normal/AO assume a roughly-base surface
  curvature; extreme stacked morphs (body-reverify §3/§4: unbounded displacement → angular
  lobes) push the surface where the baked AO creases land wrong. So the **cumulative
  displacement clamp (§3 below) is a fidelity requirement, not just an anti-monstrosity
  one** — it keeps the surface inside the envelope the maps were baked for.
- **LOD for VR.** Three quality tiers, selected by platform + distance, driven off one
  material config:
  - **Flat/PCVR near:** full stack — baked normal + detail-normal + ORM + SSS + parallax
    eyes.
  - **Quest / VR mid:** baked normal + ORM, **SSS off**, eyes drop parallax → flat iris
    sample, detail-normal fades with distance.
  - **Far / crowd NPCs:** normal only, eyes procedural-flat, brows static. `[D]`
  The creator always previews at the **highest tier** (it's a single body, close up) so
  the player edits the best-case look (see §4).
- **Eye/brow density is a fixed per-proxy cost**, not editable — the player never changes
  eyeball tessellation, so it's a flat budget line, decided once.

---

## 3. Editable in base creation vs gated; bounds against monstrosities

- **Base-creation editable:** all headline macro axes (age≥18, height, masculinity,
  muscle, weight, proportions) + the full categorized detail-modifier set (face/nose/eyes/
  ears/mouth/torso/breast/hips/limbs) via sliders AND drag-sculpt. Skin-tone + eye-color +
  brow-shape pickers (fidelity-relevant: these drive the new material params).
- **Gated OUT of base creation `[D]`:**
  - **Pregnancy.** The MH `stomach/stomach-pregnant-decr|incr` target is currently
    surfaced as the generic "belly round" slider (body-reverify §3). **Decision: remove it
    from base creation;** pregnancy is a *runtime state* (a later body-state system), not a
    character-creation knob — and its extreme belly geometry is exactly where the baked AO
    breaks. Reachable only via the future pregnancy system, not the creator.
  - Anything that requires re-UV or breaks the single atlas (none planned).
- **Bounds against monstrosities (also a fidelity guard, see §2):**
  - **Per-modifier clamp** already exists (registry range, `morph_drag.gd:365`).
  - **NEW: cumulative per-vertex displacement clamp** — cap total summed displacement per
    render vertex (e.g. ≤ some multiple of local edge length) so overlapping regions can't
    sum into angular lobes (body-reverify §2/§4). This is the missing combined bound. `[D]`
  - **Symmetry default ON for drag-sculpt** — sculpt is currently one-sided
    (body-reverify §1), which produces accidental asymmetric "monstrosity" faces. Mirror
    the picked modifier to its `l-`/`r-` twin by default, with an explicit asymmetry
    toggle (parity with the slider path which is already symmetric). `[D]`
  - These keep morphs inside the envelope the §1.1 maps were baked for.

## 4. Camera / UX + state persistence (fidelity-relevant slice)

This frame cares about preview quality and lighting, less about panel layout:

- **Default view = the FACE, front, eye-level, framed head-and-shoulders.** Current
  default shows the *back* (creator-ux §1 — `_yaw=PI` bug). The face is where 80% of
  perceived fidelity lives; open on it. `[D]` (fix the yaw, verify with a render).
- **Studio lighting rig, not one raking directional.** The current single directional
  light is what makes the matte surface read plastic (body-visual-reverify §3). Ship a
  **3-point creator lighting preset** (key + fill + warm rim) + neutral studio HDRI for
  IBL — this is half the fidelity battle and costs nothing geometrically. Provide a
  **lighting-rotate control** so the player can see how the face reads under different
  light (the only way to evaluate SSS/normal quality). `[D]`
- **Preview always renders the top quality tier** (§2) regardless of target platform, so
  the player edits the best-case look; a "preview as Quest" toggle shows the degraded tier
  honestly. `[D]`
- **Persistence:** autosave `BodyState` (+ history tree) to `user://` on change/exit,
  restore on open, real import path (creator-ux §7 — currently lost on scene switch). The
  serialized state is the sparse modifier map + the new material params (skin tone, eye
  color, brow shape) — tiny, diffs clean, fits the seed+action-log invariant.

## 5. CONCRETE, TESTABLE QUALITY BAR for visual fidelity

"Looks good" made measurable/comparable — these are the acceptance gates, each xvfb- or
render-checkable (the standing CI discipline). A change ships only if it does not regress
any green gate:

1. **Plastic-look gate (the headline).** Render the neutral face under the 3-point rig at
   the top tier; the lit render must show **visible roughness variation + surface micro-
   normal break-up** — operationalized as: the std-dev of the specular-highlight region
   luminance is ≥ a threshold above the current flat-material baseline (the current matte
   surface has near-uniform specular). Comparator: side-by-side `before.png` (today's bare
   material) vs `after.png` committed to the diagnosis-style render index; the
   plastic-vanishes-under-flat-ambient test (body-visual-reverify §3) must now show the
   *opposite* — detail that survives because it's in the normal map, not the lighting.
2. **Eye gate.** At a tight eye close-up (256² crop), the iris must show **smooth
   concentric structure (no facets)** and the iris must **parallax-shift** under a ±15°
   camera move (assert the iris-center pixel moves relative to the cornea silhouette).
   Eyes must be **seated in-socket at masc 0/50/100** (regression of body-visual-reverify
   §1 — currently fails: masc0==masc50 byte-identical renders).
3. **Seam gate.** No visible shading OR normal-map seam down the back-of-head / inner-leg
   under directional light (re-run the `bvd_head_back` / leg renders; vertex-normal seam is
   already fixed `[V]`, so this gate now guards the *tangent/normal-map* seam).
4. **Morph-validity gate.** After a large morph (e.g. weight 150 + muscle 100), the normal
   map must still read correctly (no sheared/swimming detail) — requires the tangent-rebake
   (§2); assert the morphed face's specular-variation metric stays within band of neutral.
5. **Bounds gate.** No angular silhouette lobes at max stacked morph (the cumulative clamp,
   §3) — re-run the `belly_extreme`/`thigh_extreme` renders from body-reverify §4; the
   silhouette curvature must stay below an angularity threshold.
6. **Quest budget gate.** The top tier is Forward+/PCVR only; the Quest tier (normal+ORM,
   no SSS, flat-iris) must render the creator body within the mobile frame budget — measure
   draw cost on the Mobile backend, assert it fits (the explicit cross-platform split).

The headline measurable definition of "good": **a neutral face, framed front, under the
3-point rig, at top tier, is indistinguishable in surface-quality from a reference photo-
adjacent CC0 render at thumbnail size, and shows pore-scale micro-detail + roughness
variation + believable eyes at full-screen close-up** — gates 1+2 together.

## 6. Biggest unknowns / risks (the 2-3 that decide feasibility)

1. **The offline normal/AO bake toolchain (§1.1 Tier B).** Godot has no offline baker.
   Adding **Blender-headless `bpy`** to the nix build graph is the proven route but a new,
   heavy build dependency; the alternative is an **in-Godot GPU bake pass** (lighter dep,
   more to write). **Risk: medium.** Mitigation: **Tier A (procedural detail-normal) +
   SSS + better eyes ship WITHOUT any baker** and already clear most of the plastic-look
   gate — the baked meso-normal (Tier B) is a second wave, so the frame isn't blocked on
   this decision. *Would prototype both bakers against gate 1 before committing.*
2. **Quest SSS + parallax-eye availability on the Mobile backend (§1.1C, §1.2).** `[U]` I
   did not verify whether Godot 4.6's Mobile/Compatibility renderer supports
   `subsurf_scatter` or the eye parallax shader within budget. **Risk: medium** — but
   contained by the explicit tier split (Quest already planned to drop SSS). *Would verify
   on a Quest build / the Mobile backend directly.*
3. **Tangent rebake under morph (§2).** If `body_state.bake_morphed_normals` does NOT
   rebake `ARRAY_TANGENT`, large morphs will shear the normal map (swimming pores). `[U]`
   **Risk: low-medium**, cheap to fix (mirror the normal rebake for tangents), but it's a
   hard *prerequisite* to the whole skin-normal plan being morph-valid — verify first.

Secondary/known: Gate-0 proxy-follow rebuild (eyes/brows seat correctly) is a **hard
prerequisite** to §1.2/§1.3 and is a data rebuild, not a render change — sequence it first.
No CC0 source exists for skin albedo or brow alpha-cards (verified) — both are deferred
wants with procedural fallbacks, not blockers.
