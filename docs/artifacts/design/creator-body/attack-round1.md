# Attack — round 1 (hostile review of creator-body SYNTHESIS.md)

Adversarial pass. Sole purpose: find what is wrong with `SYNTHESIS.md`. No strengths, no
verdict on readiness. Every factual attack is grounded in repo source / assets at `HEAD`
(this pass, 2026-06-23). `file:line` or asset cited; suspicions labeled "suspected, verify by X."

Severity: **BLOCKER** (design is wrong / will fail as written) / **MAJOR** (serious rework) /
**MINOR** (weakness/nit).

---

## BLOCKERS

### B1. The mirror-default mechanism (§1.3) is built on a function that does not do what is claimed, and silently fails to mirror 64 of 122 bilateral modifiers.

§1.3 ("Mirror default ON"): *"applying the same delta to the structural `l-`/`r-` registry
twin (reuses `resolve_full_names`; midline modifiers self-mirror)."*

`resolve_full_names` (`region_sliders.gd:136-148`) does **not** mirror an arbitrary registry
modifier. It is a **slider-spec resolver**: it only expands a *spec token* that `begins_with("l-")`
**and does not contain "/"**, and it hardcodes a single prefix `const BILATERAL_PREFIX :=
"armslegs/"` (`region_sliders.gd:130`). So:

- It only ever produces `armslegs/l-…` + `armslegs/r-…`. The registry has `l-`/`r-` twin
  modifiers in **four** groups, not one — counted from `modifier_registry.json`:
  `armslegs` 58, `eyes` 34, `ears` 22, `cheek` 8. `resolve_full_names` covers **only the 58
  armslegs**; the **64 eye/ear/cheek bilateral modifiers are not mirrored by it at all.**
- The sculpt path emits **registry full_names** (e.g. `armslegs/l-upperarm-muscle-decr|incr`),
  not bare spec tokens — `morph_drag.decompose_drag` works in registry full_name space. Such a
  string *contains* "/", so `resolve_full_names` takes the `else` branch and returns it
  **unchanged** (`region_sliders.gd:144-145`). It mirrors nothing on the sculpt path.
- The latest diagnosis says exactly this: *"resolve_full_names … is true FOR SLIDERS — but it
  does not apply to sculpt"* (`body-reverify.md:19-24`), and *"Arm/leg modifiers in the registry
  are SEPARATE per-side modifiers … a drag on one arm only ever picks the `l-` (or `r-`)
  modifier"* (`body-reverify.md:15-18`).

The §1.3 graft names a function and asserts it does the mirror; it does not. "Reuses
`resolve_full_names`" is a **named fix with no executable method** — a real mirror needs a new
twin-lookup (full_name `l-`↔`r-` substitution across **all** bilateral groups, plus a
self-mirror set for midline modifiers) that does not exist anywhere in the code. Quality gate
#10 ("mirror default applies the `r-` twin delta") would *fail on every non-armslegs region* and
*fail on the sculpt path entirely* if implemented as written.

### B2. §0 / §5.2 assert "proxy morph-follow is FIXED, verified" while the diagnosis set still contains a high-confidence "BROKEN" finding — and the design's own evidence (matching index keys) does **not** prove the deltas are non-negligible.

§0: *"Proxy morph-follow is FIXED. The detail index carries 188 macro target keys identical to
the body's."* I verified at `HEAD`: `base_body_proxies_detail.index.json` does now carry **188**
`macrodetails/*` keys (matches the body's 188), and the specific targets the re-verify said were
missing (`universal-female-young-averagemuscle-averageweight`, `caucasian-female-young`) are now
present. So the *index keys* match.

But two problems:

1. **The matching-keys evidence is insufficient for the claim.** `body-visual-reverify.md:55-64`
   proved BROKEN by a *byte-identical render* test (masc0==masc50, neutral==masc50 with ProxyMorph
   bypassed) — i.e. the proxy deltas were *negligible*. A target key being *present in the index*
   does not establish that its delta has non-trivial magnitude or correct sign. The synthesis
   downgrades this to "verified by a render in the quality bar, not a prerequisite" (§0) — but no
   such render exists yet; the prior render evidence on file says BROKEN. The design asserts a
   FIXED state it has not actually re-rendered. This is unearned confidence (CLAUDE.md: "Confidence
   only when earned by tangible evidence"). Suspected-correct, but **would verify by** rendering
   masc 0/50/100 and confirming the masc0==masc50 byte-identity no longer holds — which is exactly
   what gate #2 demands and what §0 has *not* done before declaring "FIXED."

2. **`body-visual-reverify.md` (Jun 23 01:03) is the newest diagnosis on disk and still says
   BROKEN.** Per the project's own diagnosis-discipline ("every verified defect must be addressed
   or consciously deferred"), the design relies on a verbal "red-team §5 resolved the stale-
   diagnosis disagreement" but never reconciles the on-disk diagnosis. An unreconciled
   contradiction in the verified-defect set is precisely the "something unexpected → stop and find
   out why" trigger. Treating a render-proven defect as resolved on the strength of an index diff
   is the confident-wrong process even if the answer is right.

### B3. §2's promised "at-rest body-fat belly control" does not exist as named; the named substitute (`stomach-tone`) is an abs-*definition* control, not a belly *volume* control — retiring the pregnancy slider leaves no at-rest belly-protrusion primitive except the global `weight` axis.

§2: *"Retire it [stomach-pregnant] from the creator surface… Base creation gets an at-rest
body-fat belly control instead (driven by `weight` + `stomach/stomach-tone`)."*

Verified the available stomach primitives (`modifier_registry.json` / `base_body_detail.index.json`):
`stomach-navel-in|out`, `stomach-navel-down|up`, `stomach-tone-decr|incr`, `stomach-pregnant-decr|incr`.
`stomach-tone` is surfaced as *"abs tone — soft → defined"* (`region_sliders.gd:58`) — it controls
abdominal muscle **definition**, not fat **protrusion**. So after retiring `stomach-pregnant`:

- There is **no dedicated at-rest belly-protrusion morph left**. The only belly-volume lever is the
  whole-body `weight` axis (which inflates everywhere, not selectively the belly).
- `body-reverify.md:43-51` confirms `stomach-pregnant` is the *only* `pregn` modifier and that it is
  the de-facto belly-roundness control today. Removing it deletes the only local belly-shape verb
  and replaces it with a definition slider that does a different thing.

This is vagueness masquerading as a decision: "a body-fat belly control" is named as if it is a
primitive, but no such primitive exists; the cited substitute changes a different attribute. A
concrete method (a *new* fat-belly target, or driving `stomach-pregnant` at reduced range from a
relabeled "soft belly" control while gating it off the pregnancy *sim*) is required and absent.

### B4. The §4 "build-time assert" guard cannot be implemented against the registry's `present` flags — every one of the 531 target `present` flags in `modifier_registry.json` is `false`, including for the volume axis option (b) binds to.

§4 Guard: *"a build-time assert (extend `body_region_sliders_test.gd`) fails if any exposed
control binds a modifier whose targets are absent from the library — so a dead control like
`BreastSize` can never silently ship again."*

Counted in `modifier_registry.json`: **531 occurrences of `"present": false` and 0 of
`"present": true`.** Specifically `breast/breast-volume-vert-down|up` — the exact axis option (b)
binds "Breast size" to — is recorded with `"present": false` for **both** its min/max targets
(`modifier_registry.json:253`). Yet those targets **are** in the live library
(`base_body_detail.index.json` has `breast/breast-volume-vert-down.target` and `…-up.target`;
12 breast keys total). So:

- The registry `present` flag is **uniformly stale/wrong** (says absent for things the library
  has). An assert keyed on `present` would either fail for *everything* (every exposed control)
  or be meaningless.
- A *correct* assert must cross-check each exposed control's target paths against
  `DetailLibrary.has_target(path)` (`detail_library.gd:78`) — i.e. against the *library index*,
  not the registry flag. The design says "extend `body_region_sliders_test.gd`" but does not state
  *which source of truth* it checks. Written against the obvious field (`present`) it is wrong;
  the design hasn't specified the method, so the guard is a named fix without an executable method.
  (The bare-macro detection it actually wants — `kind:"macro"` with `targets:[]` — is a *different*
  check than "targets absent from library" and the doc conflates them.)

### B5. The §3 cumulative-displacement soft-clamp is placed inside `bake_morphed_normals`, which the creator runs on **every drag frame** — adding per-vertex accumulation + region grouping + tanh compression to a 14,517-vertex CPU rebake on the interactive hot path, with zero cost accounting.

§3: *"During `bake_morphed_normals` (`body_state.gd:634`), accumulate per render vertex the total
applied `|Δ|`… apply a soft (tanh-style) compression."*

Verified the call graph: a drag event → `_drag_morph` → `decompose_drag` then `_apply_state()`
(`character_creator.gd:460-472`) → `_rig.apply_body_state` → the CPU morph + `bake_morphed_normals`
(`character_creator.gd:1262-1273`, comment at `:1261` "Only runs on slider changes" is itself wrong
for the drag path). `bake_morphed_normals` already does a full 14,517-vert (`render_vertex_count:
14517`) position rebuild + per-base-vertex normal accumulation every call (`body_state.gd:634-725`).

§3.1 correctly rejects runtime *subdivision* for being 4×/16× on this hot path — but then §3 adds
its **own** new per-vertex work (a second full-mesh `|Δ|` accumulation pass, region-membership
lookup per vertex, and a tanh per affected vertex) to that **same** per-drag bake, and accounts for
**none** of it. The "it's a bake-time substrate invariant, protects every path identically" framing
(§3 bullet 1) hides that on the *creator* path "bake-time" **is** "every drag frame." On Quest (the
platform §3.1 worries about) this compounds with the existing bake. The cost the design rejects for
subdivision is partly re-incurred by its own clamp, unmeasured.

### B6. The synthesis silently drops three verified defects from the diagnosis set, the most severe of which (`body-render.md` #1) is the diagnosis's own "dominant face-obscurer."

Cross-checked the design against the diagnosis set (grep over `SYNTHESIS.md` for the relevant
terms returned no hits). Dropped, with no "consciously deferred" note:

- **`body-render.md` #1 — the CC0 helper-hair "cap" renders as black slabs draping to the chest,
  covering the entire face** (the geometry probe: hair proxy spans `y 1.018..1.666`, i.e. crown to
  chest; `body_rig.gd:898-901` solid matte black, `CULL_DISABLED`; ON by default —
  `PROXY_DEFAULT_HIDDEN` leaves `hair` visible, `body_rig.gd:64`). The diagnosis calls this the
  **"featureless face" symptom #1** and "the dominant face-obscurer." The synthesis's entire §5
  fidelity story (eyes, brows, skin, lighting, face-first camera) is **moot if the default body's
  face is covered by black hair slabs.** The face-first camera (§5.4) would open *on the black
  cap.* This is the single highest-impact verified visual defect and the design does not mention it.
- **`body-render.md` #5 — MorphGlow overlay is coincident geometry with depth-test ON, a z-fight
  setup** that manifests on hover in the creator (`character_creator.gd:249-264`, `:261`
  `no_depth_test=false`, no offset). The creator is exactly the surface this design governs.
- **`body-render.md` #6 — dead region-masking index-buffer machinery** (`base_index` /
  `neutral_base_index` round-trip with lying comments) — flagged under CLAUDE.md "retire, don't
  deprecate / finish migrations." The design touches `bake_morphed_normals` heavily (§3, §5.0) but
  never addresses the dead `base_index` parameter it must thread through.

A design that claims to be "grounded in the verified diagnosis set" (§0 header) must address or
consciously defer each verified defect. These three are neither.

---

## MAJOR

### M1. §6 misstates the persistence code reality: the read/import side is NOT absent — `CreatorIO.parse_payload` and `extract_history_from_png` already exist; only the scene wiring is missing.

§6: *"add the read-back / Import path (currently write-only) and a real Import action."* and §0
implies the write side exists via `history_to_json`.

Verified `creator_io.gd`: it already has `parse_payload` (`:51-63`, parses both
`{history,current_state}` and bare BodyState dicts via `BodyState.from_dict`),
`extract_history_from_png` (`:66`), `extract_history_from_image` (`:100`). So the **read side of
CreatorIO is implemented.** What is missing is that `character_creator.gd` never *calls* it (grep:
no `parse_payload`/`extract_history`/Import in the scene). The diagnosis says this precisely
(`creator-ux.md:121-123`: "CreatorIO already has … the read side is unused/absent **here**"
— scoped to the scene). The synthesis's "currently write-only" overstates the gap; the work is
*wiring*, not *building the read path*. Minor scoping error but it mis-estimates the task.

### M2. §3's 10k-seed property test asserts "no triangle inverts" as a self-intersection proxy — but triangle non-inversion does **not** detect self-intersection, and the test cannot prove the visual no-monster property it is sold as.

§3 / Gate #1: *"(b) no triangle inverts / no area collapses below ε (self-intersection proxy)."*

A morph that pushes one region's surface *through* another (belly through thigh, breast through
breast at the midline with mirror off) produces **zero inverted triangles** — each triangle stays
locally well-formed while two surfaces interpenetrate. Non-inversion is a *local* degeneracy check;
self-intersection is a *global* (pairwise-triangle) property. Calling non-inversion a
"self-intersection proxy" is false on its face. The test as specified will pass bodies that visibly
clip into themselves. The genuine check (BVH triangle-pair intersection over the morphed mesh) is
far more expensive and is not what is written. So the headline guarantee ("it cannot make a monster
— by construction," §1.3 randomize bullet) rests on a test that does not test the failure mode that
makes a monster.

### M3. The whole §5 skin-fidelity plan is gated on R1 (tangent rebake) which is correctly diagnosed but the *fix method* is hand-waved, and the morph rebake's tangent handling has a subtlety the one-line "recompute from UVs" ignores.

§5.0 / R1: *"mirror the normal-rebake to also recompute per-vertex tangents from UVs on the baked
positions."* Verified the defect is real: `bake_morphed_normals` writes only `ARRAY_VERTEX` +
`ARRAY_NORMAL` (`body_state.gd:719-720`) and re-attaches the original blendshapes/format; tangents
are never touched. Good catch. But:

- The converter computes tangents via Lengyel and **explicitly does NOT weld them across UV seams**
  (`body_converter.gd:282-285`: "NOT welded across UV seams: a tangent is parameterised by UV, and
  split corners have distinct UVs"). The normal rebake, by contrast, **does** weld (per-base-vertex
  accumulation, `body_state.gd:691-714`). So "mirror the normal-rebake" is the wrong template — a
  faithful tangent rebake must follow the *converter's* per-render-vertex, seam-split Lengyel path,
  not the normal path's per-base-vertex weld. The design's one-liner would weld tangents and
  re-introduce the seam the converter deliberately split. Named fix, wrong method.
- This adds a *third* full-mesh pass (positions, normals, **tangents**) to the per-drag bake (cf.
  B5) — `_compute_tangents` is itself an O(tris) + O(verts) pass. Unaccounted.

### M4. §5.2 ships "gaze-fix + iris texture + cornea on existing density" while the existing density is the very thing the same section says makes the analytic iris facet — the near-term deliverable inherits the defect it defers.

§5.2 defers the denser eye proxy (R3, re-bake-gated) and says *"Until then, the gaze-fix + iris
texture + cornea improve the eye on the existing density."* But `body-visual-reverify.md:104-113`
pins the in-socket ugliness cause as: *"with ≈48 verts per eyeball the per-fragment interpolated
normal is coarse, so the analytic concentric rings quantize into a faceted, blocky iris/pupil."*
The iris is computed per-fragment from the *interpolated model normal* (`eye.gdshader:55-65`), so a
**texture** sampled in that same coarse parameterization, and a **parallax cornea** offset along a
coarsely-interpolated normal, both ride the same faceted basis. The near-term ship therefore cannot
reach the §8 gate #6(a) "smooth-iris … parallax under ±15°" without the deferred denser proxy — the
two are coupled, and the design presents the cheap slice as independently shippable. Suspected the
texture helps albedo but not the *smoothness*; would verify by rendering the eye with a sampled iris
on the 48-vert proxy.

### M5. §4 option (b) claims the volume axis is "already the region 'size' control" and "what the UI already uses," but the registry marks both its targets `present:false`, and the design never reconciles which artifact is authoritative — risking shipping a control the registry believes is dead.

§4: binds "Breast size" to `breast/breast-volume-vert-down|up` ("already in the library, already
the region 'size' control"). Verified the targets exist in the *library* index (good), but the
*registry* says `"present": false` for both (`modifier_registry.json:253`). The design's own §4
guard (B4) is meant to catch controls bound to absent targets — yet the control §4 *chooses* is
exactly one the registry flags absent. Either the registry `present` flags are authoritative (then
(b) binds a "dead" control and trips the guard) or the library index is authoritative (then the
guard must ignore `present` — see B4). The design picks (b) without resolving this, so its own
acceptance machinery is internally inconsistent with its chosen mechanism.

### M6. The "derived cup-letter readout from realized breast geometry" (§4(b)) is named as if free but is an unspecified geometry-measurement function that does not exist and has no defined method.

§4(b): *"Show an approximate cup letter as a display-only readout derived from realized breast
geometry (the same way height-cm/weight-kg are emergent)."* Height/weight emergence has actual code
(age→stature curve `body_state.gd:137-353`, cited by `body-render.md:156`). There is **no**
breast-geometry-measurement code (grep: no cup/bust-circumference *measurement* function; the
`region_sliders.gd:48` "bust circ." is an input label, not a measurement). "Cup = (bust circ −
underbust)" requires measuring two girths on the morphed mesh per state — a new geometry probe with
chest-plane definition, landmark vertices, and a calibration table to map cm-difference→letter. The
design presents this as a no-cost affordance ("preserves the affordance players want") while it is
net-new measurement infrastructure with no specified method. Vagueness masquerading as a decision.

### M7. §1.3 "always-on grab disambiguated by hit-test" is asserted to "kill the hidden-mode-keybind defect outright," but the existing pick/drag core is per-vertex and has no empty-space vs triangle hit distinction wired to camera-orbit — this is a UX redesign of the input loop presented as a settled graft.

§1.3: *"left-press on a triangle → grab+pull … left-press on empty → orbit; right-drag pan."* The
current creator gates morph on a *mode* (`character_creator.gd` `_set_sculpt_mode`, M key —
`creator-ux.md:35-48`) and, when not in sculpt mode, left-drag presumably orbits. Switching to
"hit-test decides" means the camera-orbit and the morph-grab now share the left button arbitrated by
a CPU/GPU pick every press. The pick exists (`_cpu_picker`, GPU id picker) but the *arbitration
loop* (press → pick → branch to orbit-vs-grab, with drag-start latency from the pick, and the
"press on empty space returns no triangle" path) is **new control-flow**, not present. It is a
sound idea, but "kills the defect outright" overstates a non-trivial input-loop rewrite as done.
The persistent-hint claim ("never changes because the interaction never changes") also ignores that
the *outcome* of an identical gesture now depends on sub-pixel hit-testing — a discoverability
problem of its own (did I grab or orbit? why did it do the other thing?).

### M8. R5 / §3.1 silhouette fallback is "tighter bounds OR bake-time subdivision" — but tighter bounds directly contradicts the design's headline promise that "controls mean what they say across their working range."

§3.1 fallback: *"(a) tighter bounds (lower the clamp ceiling so the allowed extreme never enters
the faceting regime)."* The clamp ceiling *is* the working range of every chest/belly/thigh control
at the extreme. Lowering it to dodge faceting means the control's drawn range no longer reaches the
shape it labels — i.e. the slider says "max curvy" and delivers less, the exact defect §3 rejected
input-space shrink to avoid ("a control whose range silently retracts"). The output clamp is sold as
*not* compromising the working range; the fallback to make the silhouette acceptable is to compromise
the working range. The two cannot both hold at the extreme. This is an internal contradiction
between §3's promise and §3.1's escape hatch, and the design does not acknowledge the tension.

---

## MINOR

### N1. §5.4 / camera default — the design says "fix yaw (likely `_yaw = 0.0`) and confirm with a render," but the diagnosis already showed the comment-math and the render *disagree* about facing, so `0.0` is a guess, not a decision.

`creator-ux.md:22-32` shows `_yaw=PI` *should* (per in-comment math + interpreted_player's "body
faces -Z") show the front, yet the render shows the **back** — so the facing convention is itself
unresolved. Picking `0.0` "likely" is the kind of blind flip the diagnosis explicitly warned against
("do not flip it blind, since the in-comment math and the render already disagree"). The design
repeats the unresolved anomaly instead of resolving it.

### N2. Several verified UX defects are dropped without a defer note: abbreviated slider labels (`creator-ux.md` #5), no shared `Theme` / 4 ad-hoc font sizes (#6), the `P` dev picker-toggle exposed in the player input map (#secondary), the 4-button export 2×2 mess (#secondary).

These are lower-severity than B6's drops but are verified defects in the diagnosis set the design
claims to ground on; none is addressed or consciously deferred.

### N3. §1.1 "~15–18 first-party archetypes" is enumerated as `feminine|androgynous|masculine` × `slim/average/athletic/curvy/heavy/muscular` = 18, but the doc then says "shipping only the combinations that read well," so the count is simultaneously asserted (18, load-bearing for the grid UX) and undercut (some pruned). The judge already flagged this set as "recurring authoring labor … the quality of the whole common path is hostage to that set being individually good" (`judge-editing-models.md:147-149`) — the synthesis restates the number without engaging the authoring-cost risk the judge raised.

### N4. §8 gate #2 demands eyes seated at masc 0/50/100 and age 18/40/70 with "masc0==masc50 byte-identical-displaced render must NO LONGER hold" — this is the *test that would invalidate §0's "FIXED" claim* (see B2). The design lists as a future gate the very check it has already used (§0) to declare the thing fixed. If §0 is right the gate is redundant; if the gate can still fail, §0's "FIXED" is premature. The design wants it both ways.

### N5. §7 says the common path is "controller-native with no pointer assumption" and the handle table "projects to flat gizmos AND future VR grab-volumes — one definition, two projections," but the handle table does not exist yet (it is "seeded from `region_sliders.gd` GROUPS"), and the VR projection is, by the design's own §7/R6, an unvalidated hypothesis. "One definition, two projections" is asserted as an architecture property of a table that has zero rows and one (also unbuilt) projection. The redteam already labeled the handle-based interaction model "unverifiable today" (`redteam-fidelity.md:148-153`).

### N6. §5.1 "Tier A is ~70% of the perceived fix and ships without any baker" — the "~70%" is an unsourced point estimate. The redteam's own framing is qualitative ("gets to *decent* … plateaus at generic," `redteam-fidelity.md:31-33`); the synthesis hardens a vibe into a number with no derivation. Minor, but it is exactly the "confidence decoupled from checked evidence" CLAUDE.md warns on.

### N7. §3 names the clamp "calibrated to local edge length" and "the faceting regime is where displacement outruns what the 14.5k-vert mesh can smoothly represent" — but offers no method to *measure* per-region edge length on the morphed mesh, no definition of "region" for the grouping the soundness depends on ("Region grouping must be correct for the soft scale to read smoothly"), and the region partition is asserted as a prerequisite of correctness while being undefined. The redteam flagged the same ("needs the region grouping to be correct," `redteam-fidelity.md:96-98`). A named dependency with no construction method.

---

## Cross-cutting observations

- **The design leans hard on `bake_morphed_normals` as the universal seam** (§3 clamp, §5.0 tangent
  rebake) without accounting that on the creator path this function is the per-drag interactive
  hot loop, not an offline bake (B5, M3). Every "bake-time, free, protects all paths" claim should
  be re-read as "per-drag-frame on a 14.5k-vert CPU pass."
- **The verified-defect reconciliation is incomplete.** B2 (proxy follow), B6 (hair cap, glow,
  dead masking), N2 (UX nits) are diagnosis findings the design either contradicts-without-render
  or silently drops. The §0 claim "Grounded in the verified diagnosis set" is not fully honored.
- **Three guarantees rest on tests that do not test the property:** no-monster (M2, non-inversion ≠
  self-intersection), the §4 guard (B4, keyed on a stale flag), proxy-follow (B2, index-keys ≠
  non-negligible deltas).
