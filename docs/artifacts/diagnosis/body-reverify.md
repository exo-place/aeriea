# Body diagnosis re-verification (2026-06-23)

Re-checked four claims against source + render evidence. No code changed.

## 1. Sculpt asymmetry — CONFIRMED (user is right)

Drag-sculpt is one-sided; there is NO mirror/symmetry anywhere in the sculpt path.

- `scripts/body/morph_drag.gd` — the entire drag core (`build_accel`, `decompose_drag`,
  `candidates_at`) is per-render-vertex. A picked vertex's candidate set is only the
  modifiers whose stored delta footprint touches THAT vertex (`morph_drag.gd:146-188`,
  `candidates_at` 211-212). No L↔R mirroring, no symmetry option, no default.
- `scripts/body/character_creator.gd:372-441` (`_apply_morph_drag` / `_end_morph_drag`)
  applies `decompose_drag` deltas straight into `_body_state.modifiers`. No mirror step.
- Arm/leg modifiers in the registry are SEPARATE per-side modifiers
  (`armslegs/l-upperarm-muscle-decr|incr` and the `r-` twin, etc. — verified in
  `assets/body/modifier_registry.json`). Their footprints sit on one side, so a drag on
  one arm only ever picks the `l-` (or `r-`) modifier for that side.
- The ONLY symmetry in the whole body system is in the SLIDER path:
  `region_sliders.gd:136-145` (`resolve_full_names`) expands a bilateral stem
  (`l-upperarm-muscle`) to BOTH `armslegs/l-…` and `armslegs/r-…` so one slider drives
  both sides. The prior diagnosis's claim about region_sliders.gd:136-145 is true FOR
  SLIDERS — but it does not apply to sculpt, which is the path the user used. Sliders
  symmetric, sculpt not.

## 2. Overlapping-region stacking — CONFIRMED (unbounded)

Per-modifier VALUE is clamped to its range, but the composed DISPLACEMENT is summed with
no cumulative/combined bound.

- `body_state.gd:_project_modifiers` (535-565) clamps each value to [-1,1] / [0,1]
  (lines 554, 563) — per-modifier only.
- `body_state.gd:bake_morphed_normals` (640-646) loops every target and calls
  `DetailLibrary.apply(key, weight, morphed)` additively.
- `detail_library.gd:104` — `morphed[ri] = morphed[ri] + Vector3(dx,dy,dz) * weight`.
  Pure accumulation. Overlapping regions (bust circ + breast volume + belly + waist +
  hips, all touching neighbouring vertices) SUM with no combined clamp anywhere.
- Net: stacking is UNBOUNDED. There is no cumulative displacement clamp in the morph
  pipeline.

## 3. Pregnancy morph editable in creator — CONFIRMED (with nuance)

- Registry has exactly ONE pregnancy-named modifier:
  `stomach/stomach-pregnant-decr|incr` (only `pregn` hit in
  `assets/body/modifier_registry.json`).
- It IS surfaced in the base creator: `region_sliders.gd:57`
  `["stomach/stomach-pregnant-decr|incr", "belly", "flat", "round"]` — in the
  "Belly & stomach" group. So the pregnancy MORPH is editable.
- Nuance: it is RELABELED "belly" (flat→round), not presented as "pregnancy", and there
  is no separate pregnancy system gating it. So it's the MakeHuman pregnant-belly target
  exposed as the generic belly-roundness slider.

## 4. Angular belly/thigh geometry — most-supported cause: sparse tessellation under
extreme stacked morph (NOT a normals bug). Confidence: medium-high.

Renders in `/tmp/geom-check/` (neutral / moderate / extreme):
- belly_neutral, belly_moderate (belly 0.6 + weight 130) — smooth, no faceting.
- thigh_neutral, thigh_moderate (weight 140) — smooth.
- belly_extreme (belly+waist+bust+hips all =1.0, weight 150),
  thigh_extreme (thigh-circ + l/r upperleg-fat =1.0, weight 150) — SHADING still smooth
  (normals correctly rebaked), but SILHOUETTE shows visible angular lobes/lumps on the
  inner thigh and belly contour.

Evidence rules out (a) normals-not-rebaked: shading is smooth at every value;
`bake_morphed_normals` recomputes area-weighted normals every morph
(`body_state.gd:653-665`). It is (b)+(c): base mesh is MakeHuman resolution
(`base_body.manifest.json`: vertex_count 19158, render_vertex_count 14517 — moderate, not
high), and extreme STACKED displacement (claim #2's unbounded sum) pushes vertices far
enough that the coarse grid can no longer represent a smooth bulge → angular silhouette
lumps. So the angularity is a downstream symptom of #2 plus the base tessellation density,
visible at high values; it is not present at moderate values.
