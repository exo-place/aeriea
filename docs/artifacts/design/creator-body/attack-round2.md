# Attack — Creator + Body synthesis v2 (round 2, hostile review)

Target: `docs/artifacts/design/creator-body/SYNTHESIS.md` (v2, dated 2026-06-23).
Method: every load-bearing "verified/fixed/resolved" claim re-checked against the actual repo at
HEAD. Citations are `file:line` or the asset. Suspicions I could not fully verify are labeled.

Severity: **BLOCKER** = executed as written, it fails / produces a wrong result / cannot be built;
**MAJOR** = significant rework, dropped requirement, or false premise that distorts the plan;
**MINOR** = real but small.

---

## BLOCKERS

### B1. The new v2 sculpt-mirror mechanism (§1.3) operates on data the drag path does not produce.

§1.3 (the headline v2 mirror fix) says:

> "The drag path emits *vertex displacements* (and registry full_names via `decompose_drag`) …
> For the raw geometric drag delta, reflect it across the body's sagittal plane: negate the
> x-component (`Δ' = (−Δx, Δy, Δz)`) and apply it at the x-mirrored anchor vertex."

This is false against the code. `decompose_drag` (`scripts/body/morph_drag.gd:320-372`) returns a
`Dictionary` of `{ full_name: value_delta }` — **registry modifier full_names mapped to scalar value
deltas**, nothing else (see the accumulation at `:361-371`, `out[full_name] = vd`). The caller
consumes exactly that and only that: `character_creator.gd:460-471` reads `deltas[full_name]` as a
scalar and adds it to `_body_state.modifiers[full_name]`. **There is no "raw geometric drag delta"
and no per-vertex displacement anywhere in the drag path** — the drag is decomposed into modifier
weights *before* any geometry is touched; the geometry is then reconstructed wholesale in
`bake_morphed_normals` from the weight vector. So "reflect the sculpt delta … negate the
x-component" has no `Δ` to act on. facts-round1 itself confirms the return shape and the bake-from-
weights path (`facts-round1.md:43`). The entire "Sculpt / drag path — x-reflect the sculpt delta"
bullet is a mechanism for a data flow that does not exist.

Consequence: the sculpt-side mirror reduces to the *registry-twin* mechanism after all (the drag
already produced full_names) — which is fine, but then the "precomputed mirror-vertex index built
from rest positions" and the sagittal-reflection math are dead inventions, and the design has not
actually specified how a sculpt edit that decomposes to a *midline* or a *non-paired* modifier
mirrors. This is the exact failure round-1 flagged (B1, `attack-round1.md:14`: "a named fix with no
executable method") reappearing in a new disguise: the v2 text adds geometry-reflection prose that
cannot run, instead of specifying the twin application on the already-emitted full_names.

### B2. The eye-fidelity plan rests on a "1064-vert CC0 eye in the pin" that does not exist.

§5.2 and R3 assert, three times, the load-bearing premise:

> "A CC0 **1064-vert eye exists** in the pin (no authoring) …"
> R3: "the §6a fidelity gate (smooth iris) **requires** it."

The only eye mesh in the vendor pin is `vendor/makehuman-cc0/data/eyes/low-poly/low-poly.obj`,
declared in `vendor/makehuman-cc0/README.md:65` as **"eyeball proxy mesh (96 verts, UV'd)"** — and
`base_body_proxies.index.json` confirms the eyes surface is `vert_count: 96` for **both eyes
combined** (~48/eye). There is **no 1064-vert eye asset** anywhere under `vendor/`
(`find vendor -iname '*eye*'` returns only the low-poly obj/mhclo and expression targets). The
README § pin (`v1.3.0`, sha pinned) does not mention any high-density eye.

Consequence: gate #6a (smooth iris, the stated reference-fidelity bar for eyes) is gated on an asset
that must be **sourced or authored from scratch** — not "no authoring," not "exists in the pin." The
"sequence it as a re-bake slice" plan (R3) silently assumes the hard part (a UV'd high-density CC0
eyeball that morph-follows) is already done. It is not. Suspected scope this hides: sourcing a CC0
high-poly eye, UV-mapping it, fitting it to the helper verts, and re-deriving its proxy_morph
anchors — none of which is "amortize against another re-bake."

### B3. §2's belly-fullness composition rule depends on a pregnancy simulation that does not exist.

§2 / R5 decides option (ii) and commits to a concrete integration contract:

> "the creator control and the sim must agree on a single write channel for this target (additive:
> `at_rest_belly + sim_pregnancy`, both clamped) … a small, named piece of sim-integration work."

There is **no pregnancy simulation in the codebase**. `grep -rln pregnan scripts/` returns exactly
one file — `scripts/body/region_sliders.gd` (the slider label), not a sim. The "additive write
channel" is a contract with a counterparty that is 0% built. So the named cost ("a single write
channel … both clamped") cannot be specified, tested, or even stubbed — there is no second writer.
This is presented as resolved ("Decided (ii)") with an owned cost, but the cost is unpayable until an
entire unscoped system exists; it should be a *deferred dependency*, like VR in §7, not a closed
decision with a concrete composition formula. As written, anyone executing §2 will bind the capped
belly control and have nothing to compose it against, and the "no shared state" guarantee is
untestable.

---

## MAJOR

### M1. §3 bounds: the central no-monster claim and the gate that's supposed to prove it are both
unverified, and the design admits it while still calling the bounds "decided."

§3 builds the whole no-monster guarantee on a "modifier→region displacement matrix" with per-region
budgets, then concedes at the end: "**Open risk:** the budget curve is unverified until that sweep
runs (§9)" and R6: "**Constants unverified until the sweep runs.**" So the load-bearing invariant of
the design (cited as "the real no-monster guarantee is §3, not [the envelope]" in §1.3) is a
mechanism whose constants, partition correctness, and even *feasibility* are unproven. That is a
plan, not a decision. Specific gaps:

- **The "matrix" is an upper bound by superposition of peak-Δ — which the design says "can over-clamp
  slightly," then waves at a "commit-only exact pass (if ever needed)."** Peak-Δ superposition across
  many overlapping modifiers (region_sliders shows bust-circ + breast-volume + underbust + waist +
  hips all touching neighboring verts, `region_sliders.gd:41-68`) is not "slightly" conservative — it
  is the *worst case* and will systematically over-clamp the common multi-slider edits the creator
  exists for. "If ever needed" is vagueness masquerading as a decision; the exact-on-commit pass is
  precisely the per-vertex pass §3 spent its whole argument avoiding, just relocated to commit — and
  the design never decides whether it's in or out.
- **The region partition is asserted "derived from the library, not hand-authored" — but a vertex
  touched by `count>0` deltas from modifiers in *many* GROUPS (which is the norm; weight/muscle/macro
  cubes touch nearly everything) belongs to many regions at once.** The design gives no rule for
  apportioning a shared vertex's budget across the regions claiming it, so "each region's projected
  summed |Δ|" is ill-defined for exactly the overlapping vertices that produce monsters. This is the
  unbounded-stacking defect (`body-reverify.md:26-40`, "CONFIRMED unbounded") — the design names a
  matrix but not the apportionment that would actually bound the sum.

### M2. The "always-on grab, no mode" graft (§1.3, R8) replaces a *working* toggle with an
unspecified arbitration loop, and the disambiguation it proposes fights the existing picker latency
it admits it has.

The current code has a real, working sculpt mode: `_sculpt_mode` toggled by `M`
(`character_creator.gd:85,538-539,590-591`) and a UI button (`:710`). The design discards it for
"press → pick → branch (orbit vs grab)." It honestly flags this as "real input-loop work" with
"drag-start latency of the pick," then mitigates with "an immediate cursor/handle highlight on a
successful pick." But the picker is the very thing with latency — you cannot show "successful pick"
*immediately* if the pick is what's slow; and a press that turns out to be an *orbit* (empty-space
miss) cannot orbit until the pick resolves and reports a miss, adding latency to camera control,
which today is instant. So the chosen design degrades the common, working interaction (orbit) to fix
a hidden-mode complaint that the existing visible `M`/button toggle does not actually have (it is not
hidden — there is a button). The rejected alternative (keep the explicit toggle) is plausibly better
and is dismissed only as "the hidden-mode defect," which is overstated given the on-screen button.

### M3. §5.2 eye plan: the shader is fully procedural with **no texture sampler**, so "re-vendor the
iris and sample it" is undescribed shader rework, not a re-vendor.

§5.2: "Re-vendor the CC0 iris … sample for iris/sclera albedo, tinted by an eye-color slider … Inputs
(gaze axis, tangent plane, view dir) exist in `eye.gdshader`." But `eye.gdshader` has **zero
`sampler2D` and zero `texture()` calls** (grep clean) — iris/sclera/limbal/pupil are all *procedural
uniforms* (`assets/body/eye.gdshader:24-44`). Re-introducing a sampled iris means adding a texture
uniform, UV/parallax sampling code, and reconciling it with the procedural rings — real shader work
the design glosses as "sample for albedo." Separately, the "eye-color slider" does not exist: there
is an `iris_color` *uniform default* in `body_rig.gd:45`, but no creator UI control
(`grep eye_color/iris scripts/body/character_creator.gd` is empty). So "tinted by an eye-color slider"
is net-new UI presented as if it's a tint of an existing control.

### M4. Persistence (§6) overstates "EXISTS — only wiring left" — the import path's parse functions
exist, but the design's own gate #4 requires behavior the wiring cannot deliver without new code.

facts-round1 (#4) and the code confirm `creator_io.gd` has `parse_payload` /
`extract_history_from_png` / `extract_history_from_image`. But gate #4 also demands "an
old-budget-hash save re-validates and snaps" and §6 demands "Content-hash the §3 bounds/budget table
into the save … re-validated and visibly snapped on load." The §3 budget table **does not exist yet**
(M1), so there is no hash to write, no validator to run, and no snap-on-load to wire. "Only scene
wiring is missing" is true for raw import but false for the budget-revalidation behavior the same
section and gate require — that is blocked behind the unbuilt §3 matrix, a sequencing dependency the
design does not call out.

### M5. The tangent-rebake prerequisite (§5.0) introduces a per-vertex pass on a path the design
elsewhere insists must stay free, and resolves the conflict by asserting an untested perception claim.

§5.0 correctly identifies that `bake_morphed_normals` never writes `ARRAY_TANGENT`
(`body_state.gd:719-720`, verified — only VERTEX+NORMAL). The fix adds "a third full-mesh pass
(positions, normals, tangents)." §3 spent its entire argument proving the per-drag bake over 14,517
verts must not grow. §5.0's reconciliation: run tangents "on commit / slider-change, with the cheap
normal-only bake during active drag (drag shows correct silhouette + lighting; tangent-dependent
normal-map detail refreshes on release)." That means **during an active sculpt drag the skin
normal-map detail is shearing/swimming** (the exact §5.0 defect) and only snaps correct on release.
The design asserts this is acceptable ("drag shows correct silhouette + lighting") without any test —
gate #7 only checks the *committed* state, never the dragging state. So the v2 revision trades a
verified-broken tangent for a verified-broken-*during-drag* tangent and calls it resolved. Suspected;
would verify by rendering a normal-mapped drag mid-motion once the map exists — which can't be done
until the map and baker (R2, unresolved) exist, i.e. it's unfalsifiable at design time.

### M6. The randomize feature (§1.3) is specified as "action-logged so the roll is reproducible"
but routes through the unverified §3 composition, so its determinism gate (#5) cannot pass until §3
lands — another silent sequencing dependency.

Gate #5 requires "same archetype + nudge sequence + randomize seed → byte-identical BodyState." But
randomize "every result through the §3 bounded composition" (§1.3). If the §3 budget constants are
"unverified until the sweep runs" (R6) and the budget table is content-hashed into saves (§6),
then the byte-identical guarantee is only stable *after* the budgets are frozen — any budget retune
changes every randomize output and breaks replay of old action logs. The design's own §6 anticipates
this for saves ("re-validated and visibly snapped") but gate #5 demands byte-identical determinism
that a post-hoc budget change would violate. The two cannot both hold across a budget retune.

---

## MINOR

### m1. §0 mis-locates the "531 present:false" facts. The claim "All 531 `present:false`" reads as if
in the detail index, but `base_body_detail.index.json` has **zero** `present` keys; the 531 live in
`modifier_registry.json` (verified: 531 false / 0 true). The count is right and facts-round1:25 cites
it correctly; the SYNTHESIS phrasing is loose about which file, which matters because §4's guard
("delta-library `count==0`") and the `present` discussion key on two different files the prose
conflates.

### m2. §0 calls the proxy detail library "188 macro anchors each `count:1219`," but only **9** entries
in `base_body_proxies_detail.index.json` have `count:1219` (verified) out of 719 total `count` keys.
The "every proxy vert nonzero on every proxy" generalization is true only for the 188 *macro* anchors
that facts-round1:15 specifically scopes; the SYNTHESIS drops the scoping and implies all anchors are
full-coverage. Minor because the morph-follow conclusion still holds for the macro axes that drive
gender; but the stated number is not what the asset shows.

### m3. Dropped diagnosis items, not addressed or consciously deferred. `hair-parts.md` FINDINGS 1-4
(default CC0 hair drapes to chest; BDCC2 hair gets zero seat offset and drapes over the face; ear
seat/idle-lean; slot coverage incomplete) and `body-reverify.md §4` (angular belly/thigh under stacked
morph — "sparse tessellation," confidence medium-high) are not in the SYNTHESIS. The hair-cap *default
hide* is addressed (§0, `9c737c6`), but the underlying hair-seat defects (a *visible* hairstyle still
drapes over the face per FINDING 2) are silently out — the design says "a real hairstyle is opt-in"
without noting that opting in re-triggers the unfixed drape. §5.3 brows/lashes is addressed; hair
geometry seating is not. Should be explicitly deferred, not omitted.

### m4. §2 anatomical claim about the borrowed geometry is unverified and probably loose. §2 justifies
option (ii) by asserting "the `stomach-pregnant` target's *geometry* is a lower-belly volume bulge —
the exact deformation a resting fuller belly needs." `stomach-pregnant-incr` has `count:350` and
`-decr` `count:144` (verified), i.e. it is a substantial, broad lower-torso morph tuned for *third-
trimester pregnancy*, not a "soft paunch." Capping it to "≤ ~0.4 of max" assumes the morph's shape at
0.4 reads as a paunch rather than a scaled-down pregnant silhouette — an unverified perceptual claim;
a pregnancy bulge at 40% may still read as "early pregnant," not "ate a big meal." Suspected; would
verify by rendering the target at 0.4 weight (the asset supports it today).

### m5. §3.1's "legitimate range = renderable range" resolves the v1 contradiction by *redefining the
range to whatever passes*, which makes gate #8 nearly tautological and quietly concedes the labels may
promise less than users expect. "Controls mean what they say … within that honest range" — but the
honest range is set *by* the faceting limit (§3 budgets), so a slider labeled "belly: round" tops out
wherever the mesh stops being smooth, which may be well short of "round." The design frames this as not
a contradiction; it's a contradiction *dissolved by lowering the promise*, and it never states what the
user-visible max actually looks like. Not a blocker (it's internally consistent now) but it trades the
v1 honesty problem for an under-delivery the design doesn't quantify.

### m6. Gate #1(b) self-interpenetration via "BVH triangle-pair intersection / signed-distance
self-clip over the morphed mesh" for **N=10,000** seeds × 14,517 verts / ~14.5k tris each is a
heavy offline test the design treats as a one-liner. The corrected check (R7) is correct that triangle
non-inversion misses interpenetration, but a real all-pairs/BVH self-intersection over 10k morphed
full-body meshes is a nontrivial test-runtime cost (suspected minutes-to-hours under xvfb), and the
canonical runner has a 60000-frame ceiling (CLAUDE.md). Unscoped test cost; would verify by timing one
BVH self-intersect pass on the morphed mesh.

---

## Areas attacked that held up

- **Tangent-not-rebaked (§0/§5.0):** verified true — `bake_morphed_normals` writes only ARRAY_VERTEX
  + ARRAY_NORMAL (`body_state.gd:719-720`); the seam-split-vs-weld distinction is correct
  (`body_converter.gd:222-224`, `_compute_normals` welds). The *prerequisite* is sound; my attack is
  on its drag-time handling (M5), not its existence.
- **BreastSize dead macro (§0/§4):** verified — `modifier_registry.json:248` `kind:"macro"`,
  `targets:[]`; the live `breast-volume-vert-down|up` axis is real and is what `region_sliders.gd:42`
  already drives. Decision (b) is grounded.
- **`present` is not a live/dead signal (§0, facts #2):** verified — 531/0 in the registry; the real
  signal is library `count` (`detail_library.gd:76,93`). The §4 guard keying on `count` is correct.
- **9c737c6 fixes (default-hair hide, forward axis):** verified in the commit and
  `body_rig.gd:69` `PROXY_DEFAULT_HIDDEN := {"genitals": true, "hair": true}`.
- **Persistence read functions exist (§6):** verified — `creator_io.gd` has the three parse functions.
  (The overstatement is the *budget-revalidation* behavior, M4, not the raw parse.)
- **`is_adult_body()` predicate exists (§2):** verified at `body_state.gd:451`, used by the interaction
  layer (`interaction_world.gd:142-143`).
- **`to_dict`/`from_dict` for archetype-as-frozen-BodyState (§1.1):** verified at
  `body_state.gd:765,785`, so the data-over-code archetype seam is real.
