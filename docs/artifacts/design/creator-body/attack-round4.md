# Attack — round 4 (hostile review of SYNTHESIS.md v4)

Hostile reviewer pass. Sole job: break the v4 design. The design's own "verified/fixed/resolved"
claims are NOT trusted; load-bearing ones re-checked against HEAD source/assets. Honestly-flagged
open risks with sound resolution plans are NOT counted as flaws (per the brief); they are only
attacked where the *plan* is unsound or missing.

Verification basis: direct re-read @ HEAD of `body_state.gd`, `character_creator.gd`,
`cpu_accel_picker.gd`, `region_sliders.gd`, `detail_library.gd`, `body_rig.gd`, `face/face_rig.gd`,
`eye.gdshader`, `modifier_registry.json` (parsed), the two detail indices, `body-reverify.md`,
`new-defects.md`, `facts-round{1,2}.md`, and `git show 9c737c6`.

---

## BLOCKER

### B-1. Retiring `resolve_full_names` (M4) breaks every bilateral slider — the function does spec-token RESOLUTION, not just mirroring.

§1.3 / M4 / R8 decide: "**Retire `resolve_full_names`** … route the slider path through the same twin
table … the bilateral-stem expansion is subsumed by the twin table (a bilateral slider sets `l-…`,
the twin rule sets `r-…`)." This conflates two *different* responsibilities and, executed as written,
breaks the arm/leg sliders.

`resolve_full_names` (`region_sliders.gd:136-145`) does TWO things:
1. **Spec-token → registry full_name resolution.** The slider GROUPS store *bare stems*, not
   registry full_names: `["l-upperarm-muscle", …]` (`region_sliders.gd:78-90`). The real registry
   modifier is `armslegs/l-upperarm-muscle-decr|incr`. `resolve_full_names` builds that string by
   prepending `BILATERAL_PREFIX` (`armslegs/`) and appending `-decr|incr` (`:141`).
2. L→R mirroring (`:142`).

The v4 twin table maps `l-`→`r-` on **full_names** (§1.3: "for every registry `full_name` containing
`l-` … substitute `l-`→`r-`"). It does **not** add the `armslegs/` prefix or the `-decr|incr` suffix.
A bare GROUPS spec token `l-upperarm-muscle` is not a registry full_name and the twin table will never
resolve it. Retiring `resolve_full_names` wholesale, as M4 directs ("delete it, don't leave it as a
parallel path"), leaves the bilateral slider with no path from spec token to modifier — the slider
goes dead. The design never names where spec-token→full_name resolution relocates to.

`resolve_full_names` is also still called by `character_creator.gd:1142` and three tests
(`body_region_sliders_test.gd:71,92,140,166`). M4 says "delete it"; the design does not account for
the three live test callers nor the creator caller, and gate #10 (M4) asserts no-double-apply but does
not assert the bilateral slider still resolves at all.

This is a genuine method gap, not an open risk: the named fix (retire the function, twin table
subsumes it) is *incorrect* — the twin table cannot subsume the stem-resolution half. Locus:
`region_sliders.gd:78-90,130,136-145`; `character_creator.gd:1142`; SYNTHESIS §1.3 M4 / R8.

---

## MAJOR

### M-1. "CORE — bone-driven gaze … the eye-forward fix landed in `9c737c6`" — false provenance; `gaze_dir` is unwired and a single shared uniform cannot drive two eyes.

§5.2 and R3 list "**CORE — bone-driven gaze. Drive `gaze_dir` from the eye-bone forward (the
eye-forward fix landed in `9c737c6`).**" as a CORE (i.e. lightweight, resting-on-existing-work)
deliverable. Two problems:

- **The cited fix is not what the design claims.** `git show 9c737c6` is *"canonical forward axis +
  FP eye-forward + hide broken default hair"* — the "FP eye-forward" is the **first-person camera**
  nudge (`eye_forward_offset := 0.12`, body_rig), so the camera sits in front of the skull rather than
  inside it. It does **nothing** to the eye *shader's* `gaze_dir`. The design borrows that commit's
  credibility for an unrelated feature.
- **`gaze_dir` is currently unwired.** `grep gaze_dir scripts/` returns nothing; the shader uniform
  defaults to the constant `vec3(0,0,1)` (`eye.gdshader:22`). "Drive `gaze_dir` from the eye-bone
  forward" is net-new feature work, not shader-tuning of existing wiring as §5.2 frames it.
- **The shared eye mesh blocks per-eye gaze with one uniform.** `eye.gdshader:8-9` states both
  eyeballs are one mesh and "both gaze the same way (forward, +Z) … a single gaze axis selects the
  iris cap." A single `gaze_dir` uniform cannot make the two eyes converge or track a point; bone-
  driven gaze that reads the *eye bone forward* would need per-eye material instances or a model-space
  trick the current single-surface shader does not support. The design states bone-driven gaze as a
  delivered CORE item without naming this.

Locus: SYNTHESIS §5.2 (CORE bone-driven gaze), R3; `eye.gdshader:8-9,22`; `git show 9c737c6`;
grep `gaze_dir` empty in scripts.

### M-2. The §3 composed-field clamp is specified per-BASE-vertex but the bake operates per-RENDER-vertex with no per-base reduction — clamping as written either cracks UV seams or costs a gather+scatter the cost estimate omits.

§3 repeatedly insists the budget is "**per base vertex** … a vertex has exactly one budget regardless
of how many region GROUPS touch it" and that the clamp "rides the existing bake … one extra read+scale
per base vertex." But the bake's `morphed` array is indexed by **render vertex** (n=14517), not base
vertex: `detail_library.apply` writes `morphed[ri]` where `ri` is a render index
(`detail_library.gd:97-104`), and `bake_morphed_normals` composes positions over render verts
(`body_state.gd:649,664-665,719`). The per-base mapping (`_render_to_base`,
`body_state.gd:618-630`) exists only for the normal pass.

If the clamp is applied **per render vertex** (the only displacement the bake actually has), then
UV-seam-split coincident render verts that share a base vertex are scaled *independently*. They start
coincident with identical δ, so for a single morph they get the identical factor — but the soft clamp
`δ'=δ·soft(B/|δ|)` is a per-vertex function of `B[v]`; if `B[v]` is assigned per *render* vertex (the
design says per base vertex, contradicting the array it runs on) and the two splits ever receive
slightly different `B`, they separate → a re-introduced seam crack, the *exact* failure §5.0 spends a
whole section avoiding for tangents. To clamp correctly per base vertex the bake must: gather
render→base displacement, reduce, clamp the base value, scatter base→render — i.e. the same
gather/scatter shape as the normal pass (`body_state.gd:705-715`), **two passes, not "one read+scale
per base vertex."** The §3 cost estimate ("one linear pass," "~25–33% overhead") undercounts this and
never reconciles the per-base claim with the per-render array. This is an unresolved
correctness-vs-cost contradiction inside the load-bearing new mechanism, not a flagged open risk.

Locus: SYNTHESIS §3 (per-base budget, "one read+scale per base vertex"); `detail_library.gd:97-104`;
`body_state.gd:649,664-665,705-715,719`.

---

## MINOR

### m-1. The import "monster" justification is largely false: headline axes AND per-modifier values are already clamped at projection, so the m5 `from_dict` clamp closes a hole projection already closes.

§0 ("`from_dict` … copies modifier values **verbatim**, with no bounds clamp — so import must
validate/clamp"), §6 slice 1, and R11 frame the verbatim `from_dict` (`body_state.gd:785-797`) as a
real monster vector that the new `from_dict` per-modifier-range clamp must close. But the existing
pipeline already clamps on the read/eval side:

- Every headline axis is clamped inside `to_blend_weights` evaluation: age (`:244,328`), height
  (`:270`), masculinity (`:282`), muscle (`:376`), weight (`:384`), proportions (`:393`).
- Every per-modifier value is clamped in `_project_modifiers` (`:554` bidirectional `[-1,1]`, `:563`
  unipolar `[0,1]`), and unknown modifier keys are silently dropped (`:546 continue`).

So a verbatim `from_dict` cannot yield an out-of-range headline or per-modifier weight at bake — the
only thing that survives is **composed stacking of in-range modifiers**, which is *not import-specific*
(sliders produce the identical stack) and is exactly what §3 exists for. The m5 `from_dict`
per-modifier clamp is therefore near-redundant with `_project_modifiers`. The design overstates import
as a distinct monster vector. (The sequencing decision "ship import after §3" is fine; the
*justification* is the overstated part.) Locus: `body_state.gd:244,270,282,376,384,393,546,554,563`;
SYNTHESIS §0 / §6 slice 1 / R11.

### m-2. Stale code comment the design quotes as if authoritative — `_apply_state` comment says the bake "Only runs on slider changes, so it's cheap," contradicting the design's own (correct) hot-path claim.

The design (facts-r1 #5, §0) correctly establishes the bake runs every mouse-motion frame during a
sculpt drag (`character_creator.gd:663` → `_apply_morph_drag` → `_apply_state` →
`bake_morphed_normals`). But the live comment at `character_creator.gd:1261` still says *"Only runs on
slider changes, so it's cheap."* This is a stale lie in the code the design builds on. Not a design
flaw per se — the design got the fact right — but the design nowhere flags that this comment is wrong,
and any executor reading the code first will be misled about the cost the entire §3/§5.0 cost analysis
hinges on. Worth a named cleanup alongside the §5.6 "lying comments" retire. Locus:
`character_creator.gd:1261` vs `:663,472`.

### m-3. B2 sculpt-refresh feasibility holds, but the design's stated rebuild trigger relies on the picker's `build()` re-reading positions it currently *caches* — the mechanism needs the OWNER to re-fetch, which the prose half-states.

§1.3/§5.5/R9 say the dirty rebuild should "re-read the live baked `ARRAY_VERTEX`." Verified the gap is
real: `_apply_state` calls `_cpu_picker.mark_dirty()` (`character_creator.gd:1271`), and on the next
pick `cpu_accel_picker.pick` does `if _dirty: build(_positions, _tris)` (`cpu_accel_picker.gd:162-163`)
— it rebuilds from the **cached `_positions`** (`:71`), which is still the frozen neutral array. So the
defect is confirmed and the design's diagnosis is right. But the fix as written ("make the dirty
rebuild actually re-read the baked verts") cannot live *inside* the picker's current `build` signature
(it takes positions as an argument and caches them) — the **owner** (`character_creator`) must re-fetch
`surface_get_arrays(0)[ARRAY_VERTEX]` and re-`build`, and also refresh `_glow_base_pos`,
`rest_positions` (`:383`), and the `decompose_drag` `positions` arg (`:461`). The design lists all
three consumers correctly but describes the trigger as a picker-internal change ("make the dirty
rebuild re-read"), which is the wrong layer — the picker has no handle to the mesh. Feasible, but the
named mechanism points at the wrong object; an executor following it literally edits the picker and
finds it has no mesh reference. Locus: `cpu_accel_picker.gd:71,162-163`;
`character_creator.gd:248,383,461,1271`; SYNTHESIS §1.3 (rebuild trigger).

### m-4. §3.1 silhouette claim partially over-credits the clamp: body-reverify §4 attributes the faceting to tessellation density, which the clamp does not fix — the design concedes this in one sentence but the gate-8 pass criterion may be unreachable within the labeled range.

`body-reverify.md:54-71` rules the angular belly/thigh a tessellation-density symptom: "SHADING still
smooth … but SILHOUETTE shows visible angular lobes," cause "(b)+(c) … the coarse grid can no longer
represent a smooth bulge." §3.1 claims the composed-field clamp "addresses the angular belly/thigh
under stacked morph defect," then concedes one sentence later it is "a *tessellation-density* co-cause
that the displacement clamp does not address." These two statements are in tension: if the angularity
is fundamentally tessellation-limited (curvature per existing edge), then bounding displacement to the
faceting threshold means the **renderable range stops well before the labeled extreme** — §3.1 admits
"a control labeled 'round' tops out where the mesh stops being smooth, possibly short of an extreme
'round.'" Gate #8 then asks the silhouette be "below the angularity threshold" *at the
`belly_extreme`/`thigh_extreme` allowed extreme* — but if the clamp set the allowed extreme to the
faceting threshold, gate #8 is near-tautological (it tests the thing the clamp defined), not an
independent check that the range is satisfying. This is acknowledged honestly enough to not be a
blocker, but the gate-8 "confirms legal range = renderable range" is self-referential and won't catch
"the honest range is too small to be fun." Suspected; would verify by rendering the clamped
`belly_extreme` and judging whether it reads as a satisfying "round" — a (b) user call the design
does route to gate #8(b), so the resolution path exists but the (a) objective half is circular.

### m-5. Nightly N=10,000 self-intersection sweep cost is understated; feasibility rests on the un-built BVH whose per-body cost the design never bounds.

Gate #1 / R7 (M6) run the full N=10,000 self-interpenetration sweep nightly, each body requiring a
full bake (~14.5k verts) plus an all-pairs triangle self-clip over ~29k triangles. Naive all-pairs is
O(t²) ≈ 4×10⁸ pairs/body × 10⁴ bodies ≈ 4×10¹²/night — infeasible. The design says "build the BVH/SDF
self-clip" so it *names* acceleration, which keeps this out of blocker territory — but it never bounds
the per-body BVH cost or shows 10k full bakes + 10k BVH self-queries fit a nightly window, and there is
**no BVH self-clip code today** (grep: the only "BVH" mention is a doc comment in
`cpu_accel_picker.gd`). This is flagged feature work (R7) with a named tool, so it is an open risk, not
a flaw — but the "nightly" feasibility assertion is unearned-confident; would verify by prototyping one
BVH self-query timing × 10k. Locus: SYNTHESIS gate #1 / R7; no self-clip in scripts/tests/tools.

### m-6. Tongue rest-offset re-derivation (m7) names a method whose landmark source may not be cleanly separable in the shared proxy mesh.

§5.6 m7 / R13: "re-derive the tongue proxy's rest attach offset … compute the mouth-cavity
centroid/AABB from the **teeth/jaw proxy verts** at rest and re-seat the tongue sub-mesh's rest
offset." The tongue is part of the single EYE/TEETH/TONGUE/GENITAL proxy mesh
(`new-defects.md:15-21`; `body_rig.gd` `_build_proxy`), sharing one global 1219-vert numbering
(SYNTHESIS §0). The method assumes the teeth-vs-tongue-vs-eye vertex partition is cleanly addressable
to isolate "teeth/jaw verts" for the centroid — but the design does not cite the vertex-range or
sub-mesh tagging that makes "teeth/jaw proxy verts" selectable, and `face_rig.gd:41-44` notes the
tongue has no expression target (so no obvious tag to key off). If the partition isn't already
labeled, "compute centroid from teeth/jaw verts" has no concrete selector. Suspected gap; would verify
by checking whether `_build_proxy` tags per-piece vertex ranges. The fix direction is sound; the
selector is unspecified. Locus: SYNTHESIS §5.6 m7 / R13; `new-defects.md:15-21`; `face_rig.gd:41-44`.

### m-7. Glow outward-offset (m4) threads the WELDED per-base normals — correct for seams, but the offset ε is unspecified and a fixed ε will under/over-shoot across the height-scale range.

§5.5 m4: offset glow verts `v + n*ε` along the threaded baked `ARRAY_NORMAL`. The normal threading is
correct (welded per-base normals, `body_state.gd:709-715`, shared at seams). But the glow overlay is a
child of the **scaled skeleton** (`character_creator.gd:284`; height applied as `skeleton.scale`,
`body_rig.gd:729-731`), so a fixed rest-space ε is multiplied by `height_scale()` and a constant ε
will read differently (z-fight vs floating halo) across the [MIN,MAX] height range. The design names
the offset direction but not that ε must be scale-relative. Minor, but "offset a small distance
outward" executed as a constant will be wrong at stature extremes. Locus: SYNTHESIS §5.5 m4;
`character_creator.gd:284`; `body_rig.gd:729-731`.

---

## Attacks attempted that FAILED to break the design (load-bearing areas verified)

- **§0 ground-truth counts** — re-parsed `modifier_registry.json`: **291 modifiers**, **531
  `present:false` inside `targets[]`, 0 true**, modifier-level present at line 19 is indeed inside
  `targets[]`. Twin pairs: **61 `l-` modifiers, 0 unpaired** (every `l-` has an `r-` twin, verified by
  substitution check). Dead counts: **14 dead in body detail index, 400 dead in proxy detail index, 9
  at count==1219 in proxy.** All §0 load-bearing numbers hold exactly. Could not break.
- **Deltas pure-SUM / no apportionment** — confirmed `detail_library.gd:104` (`morphed[ri] += …·w`)
  and per-modifier-only clamp; matches facts-r2 Q3. The §3 premise (need a composition-stage bound) is
  correctly grounded. (The per-base-vs-render execution gap is M-2, separate.)
- **Bake is the per-drag hot path** — confirmed `InputEventMouseMotion` (`:663`) → `_apply_morph_drag`
  → `_apply_state` → `bake_morphed_normals` runs every motion frame. facts-r1 #5 is correct; the
  design's cost framing rests on a true fact (the stale code comment at :1261 notwithstanding, m-2).
- **Tangents not rebaked** — `bake_morphed_normals` writes only ARRAY_VERTEX + ARRAY_NORMAL
  (`:719-720`); ARRAY_TANGENT untouched. §5.0 prerequisite is real. The seam-split-not-weld
  distinction (converter `body_converter.gd:222-224` vs the normal weld) is correctly load-bearing.
  Could not break the prerequisite claim; M5 (commit-only refresh) is a sound open risk, not a flaw.
- **Eye shader fully procedural, no VIEW/refract/parallax** — grep confirms zero `sampler2D`, zero
  `texture()`, no `VIEW`/camera/refract/parallax; only `gaze_dir`/`v_model_normal`. The M3 demotion of
  cornea parallax to OPTIONAL net-new infra is honest and correct. (The CORE *bone-driven gaze* claim
  is the separable defect, M-1; the parallax demotion itself is sound.)
- **B2 sculpt-on-morphed-body defect is real** — `_glow_base_pos` captured once
  (`character_creator.gd:242`), picker caches `_positions` and rebuilds from cache
  (`cpu_accel_picker.gd:71,162-163`), all three consumers (`:248/383`, `:461`, `:434`) read the frozen
  array. Diagnosis correct; mechanism feasible (the bake's `clear_surfaces`+`add_surface_from_arrays`
  at `body_state.gd:723-724` does leave morphed verts in `surface_get_arrays(0)`). Only the *layer* of
  the named trigger is off (m-3), not the feasibility.
- **`9c737c6` default-hair-cap + camera-front fixes** — `git show` confirms `PROXY_DEFAULT_HIDDEN`
  gains `"hair": true` and the canonical-forward/camera changes. The §0 "already fixed" claims for hair
  cap and camera hold. (Only the *eye-forward→gaze_dir* attribution is false, M-1.)
- **No XR code; no pregnancy sim; breast macro dead / volume axis live** — consistent with facts; not
  re-attacked beyond confirming the design's scoping is honest.

---

## Summary of severity

- **BLOCKER (1):** B-1 — retiring `resolve_full_names` breaks bilateral sliders (spec-token resolution
  is not subsumed by the twin table; method gap + live callers unaccounted).
- **MAJOR (2):** M-1 — bone-driven-gaze CORE rests on a misattributed commit, `gaze_dir` unwired,
  shared-mesh single-uniform can't drive two eyes; M-2 — §3 clamp per-base claim vs per-render bake
  array (seam-crack risk or undercounted gather/scatter cost).
- **MINOR (7):** m-1 import-monster justification redundant with existing projection clamps; m-2 stale
  hot-path code comment; m-3 B2 rebuild-trigger points at wrong layer; m-4 gate-8 silhouette check is
  self-referential; m-5 nightly-10k self-clip feasibility unearned; m-6 tongue landmark selector
  unspecified; m-7 glow ε not scale-relative.
