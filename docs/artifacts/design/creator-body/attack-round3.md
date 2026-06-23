# Attack — round 3 (hostile review of SYNTHESIS.md v3)

Adversarial pass. Every factual attack is grounded in the actual repo/assets re-checked @ HEAD.
The design's own "verified/fixed/resolved" labels were NOT trusted; load-bearing ones were
re-checked against the source. Severity: **BLOCKER / MAJOR / MINOR**.

Method note: verifications run via `nix develop --command python3` (NixOS per-project tools);
the bare shell has no `python3`/`jq`. Asset facts below were parsed from the actual JSON files.

---

## BLOCKERS

### B1 — The §3 apportionment matrix `D[m,v]` is mathematically invalid for the headline macro axes (it linearizes a nonlinear factor-PRODUCT).

§3 plan: "Build a **modifier→vertex displacement matrix** `D`: for each modifier (and blend axis),
its per-base-vertex `Δ` contribution at unit weight … This bounds the **summed** displacement … each
contributor `m` is attenuated by the factor `B[v]/|s[v]|`." The whole apportionment rests on
`s[v] = Σ_m D[m,v]·w[m]` being the *true* signed sum, scalable by attenuating per-modifier `w[m]`.

This is **false for the six headline axes**, which are NOT linear in their own weight. The macro
contribution is a factor-**PRODUCT**: `to_blend_weights` (`body_state.gd:471-491`) emits, per macro
cube target, `_universal_target_weight = Π anchor_val(token)` (`body_state.gd:423-432`), where the
anchor vals are themselves nonlinear splits of the axes (`_age_vals` two-segment piecewise
`body_state.gd:359-371`; `_muscle_vals`/`_weight_vals` `max(0, 2x−1)` hinges `:375-387`;
`_proportions_vals` hinge `:392-397`; the gender×age×muscle×weight×proportions product). The
delta-library `apply` then sums `delta·weight` where `weight` is that *product*
(`detail_library.gd:104`, `body_state.gd:670-676`). So a vertex's displacement from a headline axis
is **bilinear/multilinear** in several axes simultaneously — there is no per-modifier column `D[m,v]`
whose linear scaling reproduces it, and "attenuate `w[m]` by `B[v]/|s[v]|`" does not scale that
vertex's displacement by `B[v]/|s[v]|`. Worse, `_age_vals` re-routes through the CDC growth-fraction
remap (`_stature_age_macro`, `body_state.gd:327-353`) — a piecewise inversion of a stature curve — so
"unit weight Δ" for the age axis is not even well-defined. The design asserts (§3, R6)
"Exact signed sums, no over-clamping superposition" as a *resolved* item; it is not exact for the
headline axes, which are precisely the axes that drive the largest displacements (gender 0→100 moves
eyes 0.145 m per the design's own §0). The 10k-seed sweep (gate #1) tunes `B[v]` against a model that
mispredicts the actual bake for every macro-driven sample — i.e. the tuning harness is calibrating the
wrong function. **Locus:** SYNTHESIS §3; `body_state.gd:423-432,471-491,359-371,670-676`,
`detail_library.gd:104`. Suspected severity-amplifier: the detail bidirectional modifiers ARE linear
in their own weight, so the matrix is *partially* valid, which will make the bug pass small smoke
tests and fail silently on macro-heavy configurations.

### B2 — Picking, locality, and drag math all run against the FROZEN NEUTRAL mesh; §5.5 fixes only the glow visual, leaving the real defect.

`_glow_base_pos` is captured ONCE from the neutral surface (`character_creator.gd:242`) and is
**never re-read**. It is then used as: the CPU picker's ray-intersection geometry
(`_pick_body` → `rest_positions: _glow_base_pos`, `:383`), the `positions` argument to
`decompose_drag` for the **locality weight** (`_apply_morph_drag`, `:461`), and the glow geometry
(`:434`). The locality metric (`morph_drag.gd:252-271`) and the candidate pick are therefore computed
on neutral geometry while the visible/edited body is heavily morphed. On a large morph the world point
you grab no longer corresponds to the neutral vertex the picker reports, so you sculpt the wrong
region and the locality bias weights the wrong neighbourhood. §5.5 "defect 2" only rebuilds the *glow
overlay* from the morphed surface; it does not touch the picker's `rest_positions` or the locality
`positions`, and §5.5 explicitly scopes itself to "the hover/glow overlay." The build comment at
`character_creator.gd:245` ("rebuilt lazily on the next pick after a morph bake marks it dirty")
describes behavior that does not exist: `_apply_state` (`:1262-1271`) calls `_cpu_picker.mark_dirty()`
but the picker was built from `_glow_base_pos` (`:248`) which is never refreshed, so a dirty rebuild
re-reads the same neutral array. This is a verified, load-bearing correctness defect in the sculpt
path the design claims to be repairing, and it is unnamed. **Locus:** SYNTHESIS §5.5 (scope too
narrow), §1.3 (mirror grafted onto a broken pick); `character_creator.gd:242,245,383,461,1262-1271`,
`morph_drag.gd:252-271`.

---

## MAJOR

### M1 — §0 asset facts are wrong about WHERE the `present` flags live; the dead-control guard keys on the wrong file.

§0: "the **531 `present:false` flags live in `modifier_registry.json`** (531 false / 0 true); the
**detail indices have NO `present` key at all**." Re-checked: the registry has **291** modifiers and
**zero** modifier-level `present` keys; the 531 `present:false` flags live **inside each modifier's
`targets[]` array** (`{"which":"max","path":...,"present":false}`, e.g. line 19), not on the modifier.
The 531-count is right but the structural location stated is wrong, and the §4 guard ("a build-time
assert fails if any exposed control binds a modifier whose delta-library `count == 0`") will be
written against the wrong shape if it trusts §0's "modifier-level present." This is the kind of
"verified" claim the brief says to re-check. **Locus:** SYNTHESIS §0 bullet 2; `modifier_registry.json:19`.

### M2 — §0 conflates the BODY detail index with the PROXY detail index; the "9 of 719 count:1219" scope correction is attributed to the wrong file and understates the dead set.

§0 (proxy scope correction): "the proxy detail library carries **188 macro anchors**, but only **9 of
719** `count` entries are `count:1219`." Two different files:
- `base_body_detail.index.json` (the BODY library, `render_vertex_count 14517`): 719 targets = 188
  macro + 531 detail, **zero** entries with `count==1219`, **14** dead (`count==0`).
- `base_body_proxies_detail.index.json` (the PROXY library, `render_vertex_count 1219`): 719 targets,
  188 macro, **9** entries with `count==1219`, and **400 dead (`count==0`)**.

The "188 macro / 719 / 9×1219" numbers are all from the PROXY index, but §0's list of re-verified
files names `base_body_*_detail.index.json` and `base_body_proxies.index.json` (the geometry index,
which has no targets at all) — it does not name `base_body_proxies_detail.index.json`, the file the
numbers actually come from. More materially: the proxy detail library is **400/719 dead** (56%). The
dead-control guard (§4) and the morph-follow argument (§0) both ride on these counts; getting the file
identity wrong means the guard could be pointed at the body index (14 dead) when the proxy controls
(eyes/teeth/tongue) live in a library that is mostly dead. **Locus:** SYNTHESIS §0 (file list + scope
correction); `base_body_detail.index.json`, `base_body_proxies_detail.index.json`.

### M3 — §5.2 claims "view dir exists in eye.gdshader"; it does not, so procedural cornea parallax is net-new infra, not "shader-tuning."

§5.2 / R3: "Parallax/refraction cornea (procedural)… Inputs (gaze axis, tangent plane, view dir)
exist in `eye.gdshader`." Re-checked `assets/body/eye.gdshader` in full: there is **no `VIEW`, no
view-space anything, no camera input, no refract/parallax** (grep for `view|VIEW|camera|refract|
parallax` returns only the comment on line 56). The shader is driven entirely by the model-space
surface normal vs `gaze_dir` (`:60-72`); the iris is *painted on the sphere surface*, so today there
is **zero** parallax. Gate #6a's "forward-facing eyes that parallax under ±15°" cannot be satisfied by
"shader-tuning" — it requires adding a view vector and offsetting the iris along it under a cornea
depth, which is new shader logic the design elsewhere claims it is *not* doing ("this is
shader-tuning work, not new sampling/UI infra"). The cost of the eye plan is understated, and a named
gate (#6a parallax, an (a) objective check) currently cannot pass. **Locus:** SYNTHESIS §5.2, §8 gate
6a, R3; `assets/body/eye.gdshader` (no view input anywhere).

### M4 — The §1.3 twin table does not retire `resolve_full_names`; both will mirror `armslegs/` ⇒ double-apply.

§1.3: "This is the canonical mirror map (§1.3) — not `resolve_full_names`." But the design never
states `resolve_full_names` is removed, and the slider UI path still calls it
(`region_sliders.gd:136-145`) to expand `l-`-stems to both `armslegs/l-…` and `armslegs/r-…`. If the
new global twin-table apply rule ("any committed value delta `d` to `M` also applies `d` to
`twin(M)`") runs on top of the existing `resolve_full_names` expansion, an armslegs slider sets BOTH
sides via `resolve_full_names`, and then the twin rule mirrors each of those to its twin again — the
left delta lands on the right (correct), then the right delta the slider already set is re-mirrored
back to the left. Net: armslegs edits double-apply or oscillate, while eye/ear/cheek (not handled by
`resolve_full_names`) apply once. The "retire, don't deprecate" rule (CLAUDE.md) is violated by
leaving two overlapping mirror mechanisms; the design names the conflict obliquely ("not
resolve_full_names") without specifying the retirement. **Locus:** SYNTHESIS §1.3;
`region_sliders.gd:130-145`.

### M5 — §5.0 (b) "cheap tangent refresh during drag" is a SECOND full-mesh pass on the bake hot path the design itself flagged as the bottleneck — and its fallback is undefined.

§0 (facts-r1 #5): "A sculpt drag → `_apply_state` → `bake_morphed_normals` runs **every mouse-motion
frame** over all 14,517 render verts." §5.0(b) then adds, on that same per-motion frame, a full
per-render-vertex Lengyel tangent recompute ("one extra full-mesh pass on the drag frame"). The bake
already does: full delta-library sum over all active targets, then a full triangle pass for normals
(`body_state.gd:702-715`), then a full scatter (`:714-715`). Adding a third full pass that requires
per-corner UV+position gradients (Lengyel) on 14,517 verts per mouse-motion frame is **not** "cheap"
and is precisely the kind of per-drag-frame cost §3 went to great lengths to avoid; the design
acknowledges this only as a hypothetical ("If profiling … blows the drag budget"). The named fallback
— "run the cheap normal-only bake during drag **and** disable the meso (Tier-B) normal contribution
during active drag only" — has no mechanism: there is no Tier-B map yet (R2 unresolved), no
defined "disable a normal contribution mid-drag" path in the material, and no measurement of what the
drag budget even is on the lowest target. This is a perf claim presented as resolved ("RESOLVED to
option (b)") that is unmeasured and whose fallback is vapor. **Locus:** SYNTHESIS §5.0(b), R1;
`body_state.gd:634-725`.

### M6 — The "no-monster" guarantee (gate #1, self-interpenetration) is the design's central safety claim and it is unimplemented, uncosted-in-reality, and gated behind a check the design admits may not run per-PR.

§3 / gate #1(b): "no self-interpenetration — a real BVH triangle-pair / signed-distance self-clip over
the morphed mesh." This is the actual no-monster guarantee (the AABB and per-vertex budget alone do
not prevent a surface folding through itself). The design's own scoping (gate #1, R7) concedes the
full N=10,000 all-pairs check is "heavy" and proposes running full-N "nightly / looser tier" with only
a "smaller smoke-N per PR." So the headline safety property is: (a) never implemented today,
(b) only fully exercised nightly, (c) the per-PR gate runs a reduced sample that can pass while a
monster-producing region of the legal envelope is never sampled. A "broadphase BVH over touched
regions" can miss self-intersections between two regions that are both "touched" but distant in the
BVH partition (e.g. a folded belly meeting a thigh). The guarantee is asserted as the substrate
invariant that "protects every path" but is the least-built, least-tested item in the design.
**Locus:** SYNTHESIS §3, §8 gate #1, R7.

---

## MINOR

### m1 — §2 belly-cap "≤~0.4 reads as paunch" is admitted-unverified, and the verification it defers to may invalidate the whole decision (ii).

§2/R5 flags this honestly ("not verified … verify by rendering at 0.4"), but the decision (ii) is
recorded as the *default* and the entire §2 belly mechanism is built on it. `stomach-pregnant-incr`
has `count:350` (verified, `base_body_detail.index.json`) — a broad lower-torso morph. If the deferred
render shows 0.4 still reads pregnant, the design's stated fallback (option (i), author a new
fat-belly target) is a recurring asset+bake cost the design elsewhere treats as undesirable, and the
"cleanly feasible" framing of (ii) collapses. A default decision resting on an unrun perceptual check
is vagueness-as-decision. **Locus:** SYNTHESIS §2, R5; `base_body_detail.index.json` (`count:350`).

### m2 — §3.2 versioned-bounds determinism assumes byte-identical floating-point apportionment across platforms; the apportionment is iterative min-over-vertices and order-sensitive.

Gate #5 / §3.2: "same archetype + nudge + seed + bounds version → **byte-identical** `BodyState` and
baked mesh across runs/platforms." The apportionment (§3) computes per-modifier global attenuation as
"the **min over the vertices it touches** of those factors," then re-scales — a reduction over a
vertex set whose float results depend on summation order and platform FMA/SIMD behavior. Combined with
the existing CPU bake's float accumulation (`detail_library.gd:97-104`, `body_state.gd:664-665`),
byte-identical cross-platform mesh equality is a strong claim the design asserts without addressing
float non-associativity. The pre-apportionment pipeline at least had a fixed sorted-key sum
(`body_state.gd:671-673`); the new min-factor reduction adds an order-dependent step. **Locus:**
SYNTHESIS §3, §3.2, gate #5.

### m3 — §0 self-mirror claim ("midline modifiers self-mirror; the delta is its own mirror — applies once") is stated as a no-op but the apply rule as written would double it.

§1.3: "Midline modifiers (no `l-`/`r-` form) **self-mirror**" + apply rule "any committed delta `d`
to `M` also applies `d` to `twin(M)`." If `twin(M) == M` for a midline modifier, the rule literally
applies `d` to `M` twice (once as the edit, once as the mirror) unless a special case suppresses it —
but the design explicitly says "no special case." Either the rule needs `if twin(M) != M`, or midline
edits double. The text claims self-mirror is "trivial, no special case," which is contradicted by the
apply rule's own wording. **Locus:** SYNTHESIS §1.3.

### m4 — §5.5 glow fix offsets along "morphed vertex normals," but the glow overlay reuses the body's stored normals which the bake welds per-base-vertex — seam verts share a normal, so the outward offset will be inconsistent at UV seams (the same seam class §5.0 worries about).

§5.5 defect-3 fix: "offset the overlay verts a small distance outward along the (morphed) vertex
normals." The baked normals are per-base-vertex welded then scattered (`body_state.gd:709-715`), so
coincident seam render-verts share one normal — fine — but the glow overlay is built on the body's
render-vertex topology (`_glow_tris`, `character_creator.gd:435`); offsetting along shared welded
normals is consistent, yet the design does not specify *which* normal array it reads (the overlay mesh
has no normals of its own; `_rebuild_glow_mesh` builds ARRAY_VERTEX/INDEX/COLOR only, `:432-438`). The
fix names "morphed vertex normals" as if they are available to the overlay; they are not threaded
there today. Minor because it is a wiring detail, but it is a fix "named without a concrete executable
method." **Locus:** SYNTHESIS §5.5; `character_creator.gd:420-440`.

### m5 — §6 slice-1 "import is wiring only" understates: imported PNG/JSON state must pass the §3 bounds it was authored before §3 exists, or it can load a monster.

§6 sequences raw import (slice 1, "no dependency on §3") before budget revalidation (slice 2, after
§3). But an imported `BodyState` from an external/older source can carry arbitrary modifier values
(the parse path does not clamp beyond per-modifier range — `from_dict`, `body_state.gd:785-797`,
copies values verbatim). Shipping import before any composition bound means slice 1 can load a body
that violates the very no-monster invariant §3 is built to guarantee, with no guard until slice 2.
The sequencing is presented as a clean dependency resolution; it actually opens a window where the
substrate invariant is unenforceable on the one path (import) that takes untrusted input. **Locus:**
SYNTHESIS §6, R10; `body_state.gd:785-797`.

### m6 — §1.3 "61 pairs … complete … every `l-` has its `r-` twin (verified)" is true today but the twin table is built by string substitution that will silently drop any future unpaired `l-` modifier rather than failing loud.

Verified: 61 `l-` modifiers, all 61 have `r-` twins, 61 `r-` modifiers (symmetric). The claim holds
@ HEAD. But the mechanism ("substitute `l-`→`r-`; keep the pair iff the twin exists") *silently
discards* an `l-` modifier with no twin — so a future registry addition of an asymmetric `l-`
modifier would silently become unmirrored with no test catching it (the completeness is asserted once,
not guarded). Minor/forward-looking: add a build-time assert that every `l-` has an `r-`. **Locus:**
SYNTHESIS §0, §1.3; `modifier_registry.json` (61/61 verified).

### m7 — Gate #2 adds a "tongue centroid within mouth-cavity AABB" assert but §5.6 only *suspects* the tongue bind/offset cause ("suspect the proxy piece's bind transform … verify") — the fix is named without a method.

§5.6: "suspect the proxy piece's **bind transform / morph-follow offset** for the tongue surface."
That is a diagnosis-to-do, not a fix. The gate is defined, but the actual correction ("fix proxy
bind/offset") has no concrete change identified — it may turn out to be a data fix in
`base_body_proxies.index.json`, a `_build_proxy` transform, or a `proxy_morph` offset, and the design
commits to none. Vagueness-as-decision for a folded-in defect. **Locus:** SYNTHESIS §5.6, R12;
`new-defects.md` defect 1.

---

## Cross-check against requirements the design might silently drop

Checked `diagnosis/body-reverify.md` (4 confirmed defects), `new-defects.md` (3 defects), and the
folded items. Accounted for: sculpt asymmetry (§1.3), unbounded stacking (§3), pregnancy-in-creator
(§2), angular silhouette (§3.1), tongue (§5.6), glow-neutral (§5.5 d2), glow-clip (§5.5 d3). **Not
dropped at the requirement level**, but see B2 (the glow fix is too narrow — the *picker/locality*
neutral-staleness, the root of the same `_glow_base_pos` defect, is not in scope) and m5 (import
window). One genuinely un-addressed item: `body-reverify.md §4` attributes angularity to "base
tessellation density" as a co-cause; §3.1's apportionment bounds the *summed displacement* but the
hands/feet sparse-density faceting is deferred ("meso-baked hard, local subdivision deferred") —
acceptable as named, but the design's claim that §3 "addresses the angular belly/thigh defect … bounded
by construction" rests on B1's matrix being correct, which it is not for macro-driven (weight 150)
stacks — the exact case `body-reverify.md` rendered.

---

## Attacks attempted that did NOT break (reported, not softened)

- **l-/r- pair completeness** (§0): re-parsed the registry — 61 `l-`, 61 `r-`, all 61 paired, 0
  unpaired. The completeness claim holds today (the only residual is m6, a guard-against-regression
  nit).
- **`breast/BreastSize` is a dead macro** (§0, §4): verified `kind:"macro"`, `targets:[]` in the
  registry; `_project_modifiers` skips `KIND_MACRO` (`body_state.gd:551-552`). The live volume axis
  `breast/breast-volume-vert-up|down` is present with `count` 369/244 (`base_body_detail.index.json`).
  Decision (b) stands on verified facts.
- **Tangents not rebaked under morph** (§0/§5.0 prereq): `bake_morphed_normals` writes only
  ARRAY_VERTEX (`:719`) and ARRAY_NORMAL (`:720`); ARRAY_TANGENT is never recomputed. Verified — the
  prereq is real. (The *drag-time* handling for it is attacked in M5; the diagnosis itself is sound.)
- **Pure additive sum, no apportionment today** (§0): `detail_library.gd:104` and
  `body_state.gd:664-665` are pure `+=`. Verified — facts-r2 Q3 holds. (The *proposed* apportionment
  is attacked in B1.)
- **Eye shader is fully procedural, no sampler2D** (§0/§5.2): verified — zero `sampler2D`/`texture()`
  in `eye.gdshader`. (The parallax *claim built on it* is attacked in M3.)
