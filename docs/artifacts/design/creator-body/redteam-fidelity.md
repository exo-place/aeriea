# Red-team — shared fidelity/bounds/semantics assumptions (creator-body candidates)

Adversarial pass over the assumptions all four candidate designs converge on. `[V]` =
verified against repo source / pinned MakeHuman tree
(`/nix/store/f17xilfqj8v2xphny6qfy4xvp8pzg4mi-source/makehuman`) this pass. `[U]` =
unverified, check named.

---

## 1. "Procedural detail-normal + roughness + SSS → genuinely good skin" — OPTIMISTIC

- The mechanism is sound and ships cheap: mesh is tangent-ready (`body_converter.gd`
  writes `ARRAY_TANGENT`) `[V]`, Forward+ `StandardMaterial3D` has `detail_normal` +
  `subsurf_scatter` (engine-native). SSS removes the worst "wax" read; a roughness map
  killing the flat 0.7 is the single biggest cheap win.
- But "genuinely good / reference-quality" is the over-claim. A **tiling Worley/value-noise
  pore normal is uniform high-frequency grain** — it has no *meso* structure (nasolabial
  fold shadowing, lip/knuckle/collarbone creases, asymmetric pore density face vs body).
  That meso layer is what separates "reads as skin" from "reads as plastic with a noise
  filter." Procedural grain alone plateaus at *generic*, not *good*.
- The honest meso path is **fidelity-first's Tier B: bake a normal+AO from a subdivided
  high-poly** — and that needs an **offline baker Godot does not have** (Blender-headless
  `bpy`, a new heavy build dep, or an in-Godot GPU bake to write). That cost is real and
  the candidates that say "achievable today" gloss it.
- Asset reality `[V]`: MakeHuman v1.3.0 ships **ZERO PBR skin maps** — no albedo, normal,
  bump, or roughness texture anywhere; the skin is a **litsphere matcap** (`skinmat_*.png`
  256²) + procedural `autoBlendSkin`, useless under dynamic PBR/VR light. Constrained-
  parametric's hope that "MakeHuman ships a default skin we can map to the MH UVs" is
  **WRONG** — there is no usable skin PNG to map. Every skin map must be generated or
  sourced CC0 (Poly Haven / ambientCG skin detail — license check at fetch `[U]`).
- **Cost/risk:** detail-normal + roughness + SSS = a few hours, ships first, gets to
  *decent*. Reference-quality needs the baker toolchain decision (medium dep risk) AND
  authored/sourced meso maps. Don't promise "genuinely good" from procedural grain alone.

## 2. "No runtime subdivision — just normal-map the 14.5k mesh" — SOUND for shading, but it
   HIDES a silhouette problem behind bounds (the cross-check holds)

- Correct that the *plastic look* is shading not density (flat-ambient test), and runtime
  Catmull-Clark on the per-frame CPU-morph hot path (`apply_morph_cpu` →
  `bake_morphed_normals`) would be 4×/16× cost every drag — rightly rejected, fatal on
  Quest. Normal maps are the right call **for shading**.
- The cross-check is exactly right: **a normal map does not fix a silhouette.** The
  verified angular belly/thigh at extreme stacked morphs is a *geometry* artifact —
  14.5k verts can't represent the displacement, so the outline goes faceted. A tangent-
  space normal map rides on the (still angular) geometry and changes nothing at the
  silhouette edge. So "no subdivision is correct" is **conditional**: it is only true *if
  the bounds keep morphs out of the faceting regime.* At the edge of the allowed range the
  silhouette WILL face — and the bounds (§4) are the only thing standing between the
  shipped product and visible lumps. They are not separately hiding the problem; the whole
  plan's silhouette quality is **load-bearing on the clamp being tuned correctly.**
- Extra defect the candidates mostly under-weight: `bake_morphed_normals` writes only
  `ARRAY_VERTEX` + `ARRAY_NORMAL` and re-adds the surface with the **original (neutral)
  tangents** — it does **NOT rebake `ARRAY_TANGENT`** `[V]` (body_state.gd:719-724). So
  under any large morph the tangent frame is stale → the skin normal map **shears/swims**.
  Only fidelity-first flags this; it is a HARD prerequisite to the entire skin-normal plan
  and currently broken. Cheap to fix (mirror the normal rebake), but must be done first.
- **Verdict:** no-subdivision is sound for shading + cheap, WRONG as a silhouette fix.
  Genuine fidelity at the edges depends entirely on the clamp + on adding tangent rebake.
  Hands/feet (genuinely sparse MH density) remain a place geometry shows that no map fixes.

## 3. Breast-size fix = "import cup cube + add factor tokens, same proven path" — SOUND
   mechanism, scope UNDER-STATED

- Mechanism is genuinely clean and reuses the existing factor-product path verbatim
  (`_decode_macro_factors` :405, `_universal_target_weight` :423, `_muscle_vals`/
  `_weight_vals` :375/:383) `[V]`. The dead macro is confirmed: `_project_modifiers`
  `continue`s on `KIND_MACRO` (:551-552), and no `*cup*`/`*firmness*` target is in the
  detail index `[V]`. So the diagnosis and the fix shape are right.
- The understated part is **how big the cube is: 216 breast `*cup*` target files** in the
  pin (`data/targets/breast/`, full age×gender×muscle×weight×{min,average,max}cup×
  {min,average,max}firmness product), 228 breast targets total `[V]` — candidates that say
  "a few extra targets" or "200+ for a coarser result" undersell/oversell inconsistently;
  the real number is 216. Plus: **the breast cube is NOT vendored** (`vendor/makehuman-cc0/`
  has no breast targets) — so this needs a vendoring step (or Nix-fetch path) on top of the
  code, and a **full detail-library re-bake** (`nix build .#body-proxies` /
  body_proxy_build). Code delta itself is small (2 token consts, 2 val splitters, 2 decode
  branches, 2 product factors). Risk: the macro cup cube and the directional
  `breast-volume-*` axes BOTH touch chest verts → they overlap → must share a §4 region
  budget or they double-count.
- **Verdict:** mechanism sound; real cost = vendor 216 targets + re-bake + region-budget
  coordination, not just "add tokens." `direct-manipulation`'s alternative (drop the dead
  macro, keep the directional axis, compute a cup *readout* from geometry) is the honest
  cheaper option and worth weighing — 216 targets for a 3-anchor coarse axis is a lot.

## 4. Cumulative per-vertex displacement clamp (anti-monster) — SOUND layer, real tuning risk

- Confirmed net-new: only per-modifier range clamps exist (`_project_modifiers` :554/:563)
  `[V]`; no cumulative/summed-displacement bound anywhere. The artifact (overlapping regions
  summing into angular lobes) is real and per-modifier clamps provably can't fix it
  (combinatorial). So the mechanism is needed.
- Choosing to clamp the **output** (post-sum per-vertex / per-region peak displacement,
  calibrated to local edge length so it's tessellation-aware) over the **input envelope** is
  the right layer — it protects every path (slider + sculpt) at once and bounds exactly the
  thing that causes faceting. `direct-manipulation`'s post-sum *region scaling* (scale
  contributing deltas when the region L2 peak exceeds budget) is the least-mushy variant.
- Failure modes: (a) a hard per-vertex clamp creates a **visible flat "ceiling" plateau** and
  a kink at the clamp boundary — reads as a dent, not a smooth cap; soft/region-scaled
  clamping avoids it but needs the region grouping to be correct. (b) The clamp is **calibrated
  to the bake** — it doubles as the §1.1 fidelity guard (keeps the surface inside the envelope
  the normal/AO was baked for), so it can't be tuned purely for "no monster"; it's coupled to
  the map bake and must be re-tuned if the bake changes. (c) The edge-length-keyed threshold is
  an **empirical sweep** (the value where faceting begins) — unverified, flagged by candidates.
- **Verdict:** right layer, right idea. Net-new code + an empirical calibration sweep +
  coupling to the map bake. Use soft/region-scaled, not hard per-vertex, to avoid mush.

## 5. Eyes: "denser proxy + sample CC0 iris + parallax cornea" — iris source REAL but mis-located;
   proxy is NOT cleanly swappable — OPTIMISTIC→partly WRONG

- The CC0 iris is real and good: `data/eyes/materials/brown_eye.png`, **1024×1024 RGBA,
  CC0** (per-file CC0 header on `brown.mhmat`, covered by LICENSE §C) `[V]`. There is also
  a CC0 **high-poly eye, 1064 verts** `[V]` — a denser eyeball already exists, no need to
  author one. BUT: **`brown_eye.png` is NOT in `vendor/makehuman-cc0/`** — the vendor README
  states it was *deliberately removed* when the eye shader went procedural. So fidelity-
  first's "it's already in the licensed tree" is **half-wrong**: it's in the *pinned source*
  but must be **re-vendored** (or pulled via Nix). Real, usable, but a re-vendor step.
- The entanglement flag is **confirmed and serious.** The proxy is **ONE ArrayMesh, many
  surfaces sharing a GLOBAL proxy-vertex numbering** (`base_body_proxies.index.json`:
  `total_vertex_count: 1219`; eyes = global verts 0–95, eyebrows 96–127, lashes 128–159,
  teeth 160–295, tongue 296–548, genitals 549+) `[V]`, and the detail-morph delta library is
  keyed against that global numbering. So swapping eyes (96→~1000 verts) **shifts every
  downstream surface's `vert_offset` and invalidates the entire shared detail library** — a
  full proxy + library re-bake, not a "drop in a denser sphere." The eye is NOT a clean
  swappable surface. `direct-manipulation`'s "authoring a denser eye sphere fits the pipeline"
  is true only because the whole library is re-baked anyway; it is not isolated.
- Proxy-follow disagreement RESOLVED `[V]`: the detail index now carries **188 macrodetails
  target keys** — the proxy library WAS rebuilt to follow the gender/age macro.
  `direct-manipulation`'s "FIXED, 188 macro deltas" is correct; fidelity-first and
  constrained-parametric citing "proxy follow STILL broken" are working from a **stale
  diagnosis** (their Gate-0 "blocking prerequisite" is largely already done — verify with a
  masc 0/50/100 render, but the data is there).
- Parallax/refraction cornea: sound, well-trodden, inputs exist — `[U]` on Quest Mobile
  backend budget.
- **Verdict:** iris asset real+CC0 but needs re-vendor; denser eye exists (1064-vert
  high-poly); proxy is entangled via global vert numbering → eye swap forces a full library
  re-bake; the "blocking" follow fix is mostly already shipped (stale in 2 candidates).

## 6. VR with zero XR code — WRONG to treat as a small prerequisite; quiet dependencies exist

- Confirmed: **no `OpenXR`/`XR*` references in `scripts/`** `[V]` — VR is 0% implemented,
  not partial. This is not a "wire up a toggle" task: OpenXR enablement + an XR camera/origin
  rig + per-eye stereo rendering + controller input mapping + comfort/locomotion is a
  substantial workstream, and it gates the cross-platform parity commitment (DESIGN.md).
- Quiet dependencies the fidelity plan leans on that VR doesn't-yet-support: (a) the **Quest
  Mobile/Compatibility renderer tier** (SSS-off, flat-iris, faded detail-normal) is asserted
  as a clean fallback, but SSS/parallax availability + frame budget on the Mobile backend is
  `[U]` *and untestable until an XR build exists* — the "explicit honest split" is currently
  an unvalidated promise. (b) `direct-manipulation` makes **grab-handles "the primary VR
  affordance"** — a UX whose feel cannot be validated without XR, so that candidate's core
  interaction model is unverifiable today. (c) The whole "creator previews at top tier" story
  assumes a desktop/PCVR path; the Quest degraded tier has never rendered.
- **Verdict:** VR-from-zero is a large prerequisite, not a footnote. No *flat* fidelity choice
  breaks without it, but the Quest tier claims and the handle-based interaction model are
  **unvalidated until XR exists** — treat them as design hypotheses, not settled.

---

## Cross-cutting: the shared blind spot

All four lean on "tangents exist → normal map is a drop-in." Tangents exist on the *neutral*
mesh `[V]`, but the morph rebake (`bake_morphed_normals`) **never rebakes them** `[V]` — so
the normal map shears under exactly the large morphs the creator is for. Three of four
candidates miss this. It is the single most load-bearing unverified-until-now defect: the
whole skin-fidelity plan is morph-invalid until tangent rebake is added. Fix it first, before
any skin map work.
