# Attack — round 6 (hostile review of SYNTHESIS.md v6)

Hostile reviewer pass. Sole job: break the design. Strengths omitted by mandate.
Ground truth re-checked against code/assets @ HEAD; load-bearing "verified/fixed/
dissolved" claims independently re-verified rather than trusted. Acknowledged open
risks WITH a sound resolution-during-execution plan are NOT ranked BLOCKER/MAJOR;
they are attacked only where the plan is unsound or missing.

Severity: **BLOCKER** (wrong / contradictory / infeasible / fix named without an
executable method) · **MAJOR** · **MINOR**.

---

## BLOCKER

### B1 — The cap/extremeness/ratchet model has NO concrete state model; the sculpt clamp is wired to a value that is FROZEN AT BUILD.

This is the heart of the v6 rewrite and the prompt's first pressure-test. The design
asserts (§3.1, l.394-396) that for sculpt, "v6 clamps to the *current cap* instead —
a tighter ceiling at the same modifier-space layer." But the actual clamp the design
points at lives **inside `decompose_drag`**, against `r["range"]`
(`morph_drag.gd:365` `clampf(cur + share*raw, rng[0], rng[1])`), and that `range` is
**not a live value** — it is copied from the registry entry into every per-vertex
candidate dict ONCE at `build()` time:

- `morph_drag.gd:156` `var rng: Array = e["range"]`
- `:173` `var rangef := [float(rng[0]), float(rng[1])]`
- `:178-179` the `rangef` is stored into each `cand` dict in `_vert_candidates[ri]`.

So the clamp ceiling is baked into thousands of candidate dictionaries at build. The
cap is, by the design's own model, **dynamic**: the extremeness slider raises/lowers
it continuously (§3.1 l.388-391), and the inward ratchet makes the *effective* ceiling
`max(current_value, current_cap)` **per control** (l.401-404). Neither of those can be
expressed by mutating a frozen-at-build `rangef`. The design never says what stores the
cap, never says how the per-vertex candidate clamp learns the current cap or the
ratchet ceiling, and never says where the per-control ratchet state lives. "Clamps to
the current cap instead" is **vagueness masquerading as a decision** — it names no
executable method at the only place the clamp actually exists.

Concretely unanswered, each load-bearing:
- **What stores the cap-vs-current relationship?** The ratchet ceiling is
  `max(current_value, current_cap)` — this needs, per control, BOTH the current value
  (lives in `BodyState.modifiers`) AND a memory of "was this set under extremeness."
  But `BodyState.modifiers` is a bare `{full_name: float}` (`body_state.gd:790-792`)
  with no per-control cap/extremeness companion. The ratchet **needs per-control state**
  that does not exist and is not designed.
- **The clamp is in two unrelated places** that the design treats as one: the *slider*
  path clamps in `_project_modifiers` (`body_state.gd:554,563`, hard `[-1,1]`/`[0,1]`)
  and the *sculpt* path clamps in `decompose_drag` (`morph_drag.gd:365`, the
  build-frozen `rangef`). To make caps real, BOTH must consult the same live cap+ratchet
  state. The design asserts a single "value layer" substrate invariant (l.411-414) but
  the code has two clamp sites with different range sources, and v6 designs neither.

This is not "an open constant to tune later" (which would be a fine open risk) — it is
the **mechanism itself** left unspecified at its only real integration point, while the
prose claims it is decided and that it "adds nothing to the bake hot path." A fix named
without a concrete executable method = BLOCKER.

### B2 — "Stacks bounded by the SUM of caps" does NOT prevent the user's reported monstrous stacking — it is a loose, often-meaningless bound, and the design presents it as the stacking guarantee.

§3.1 l.405-409 and R6 claim the per-control caps "already bound the stack" because
"the maximum combined displacement is just the sum of the per-control caps." Re-checked
against the composition path: deltas are pure-sum (`detail_library.gd:104`
`morphed[ri] += Vector3(dx,dy,dz)*weight`), confirmed. But "sum of caps" bounds the
combined displacement **only in the trivial sense that a sum of bounded terms is
bounded** — it says nothing about whether that sum is anatomically sane. The user's
reported defect was *monstrous stacking*: multiple separately-reasonable axes summing
into a deformed body. "Bounded by the sum of caps" is exactly the bound that is too
loose to prevent that — if waist-circ, torso-depth, weight, apple-distribution, and
hip-scale are each individually capped at a "reads human alone" value (§3.1 l.385-387),
their **sum** at the abdomen can still be grotesque, because the caps were validated
**per control in isolation** (§8 #1 validates "every control value ≤ its default cap"
and "body AABB within bounds" — but the cap *constants* are tuned for "human alone,"
l.385-387, 716-717).

The design even concedes the danger and then doesn't close it: §3.2 l.438-445 admits
"a folded belly meeting a thigh at *combined* extremes" can self-intersect and demotes
that to monitoring. But combined-at-DEFAULT-caps is the user's actual complaint, and the
only guard for it is §8 #1's 10k sweep at default caps asserting "no self-intersection"
— which is a *property test of the constants*, not of the model. If that sweep finds
monstrous-but-not-self-intersecting stacks (likely — self-intersection is a much weaker
condition than "looks monstrous"), the model has **no lever** to fix it except hand-
lowering individual caps until the worst *pairwise sums* behave, which re-introduces
exactly the coupled, hard-to-tune multi-axis budget the v6 rewrite deleted to escape.
The honest statement is: v6 **does not have a combined-extreme bound**; it has per-axis
bounds and a hope that their sum behaves, plus a monitoring check that is explicitly
allowed to fail at extremes and only PASS/FAIL-gated on the strictly-weaker
self-intersection metric at default. Presenting "sum of caps" as the answer to
monstrous stacking is a **false claim that the stacking problem is solved**. BLOCKER:
the central user-reported failure mode is not actually bounded by the chosen mechanism.

### B3 — The extremeness gate's scope (global vs per-control) is UNDECIDED, and the two readings give materially different, contradictory behavior — yet the design depends on a specific reading in several places.

The prompt asks directly. The design never decides. §3.1 l.388-391 describes "an
extremeness slider (0 = default caps; >0 raises caps toward the control's hard range)"
— singular, reads global. But l.385-387 says "*every control* has a default cap" and
the ratchet is described per-control (l.401-404). §8 #1 (l.709-721) runs a sweep "at
raised extremeness" as one monitoring pass, implying a single global setting. The
contradiction bites:

- If **global**, then raising extremeness to author one deliberately-huge bust ALSO
  unlocks the extreme range of all 291 modifiers simultaneously — and randomize, blend,
  and import all become extreme-capable at once. The "randomize NEVER produces an
  extreme body unless extremeness is explicitly on" guarantee (l.321-322) then means a
  single global flip makes randomize able to produce a fully monstrous body across every
  axis, which is precisely the no-monsters-by-default intent inverted by one toggle.
- If **per-control**, the per-control ratchet state and per-control extremeness UI must
  exist (291 controls), and the save must record per-control extremeness, not "the
  extremeness setting" (singular, l.655, 662, 736). The save schema as designed
  (records "the extremeness setting") **cannot round-trip** a per-control gate, so
  determinism gate #5 (l.734-737) would silently lose per-control extremeness on load.

The design uses "the extremeness setting" (singular) in the save/replay/import machinery
(§3.3 l.456, §6 l.655/662, §8 #5 l.736) — committing to global there — while describing
per-control caps and per-control ratchet in §3.1. These are inconsistent. An undecided,
internally-contradictory scope on the load-bearing new mechanism = BLOCKER.

---

## MAJOR

### M1 — Beyond-cap value on save/load/randomize is under-specified and the import re-clamp as written can DESTROY legitimately-authored extreme bodies.

The prompt asks "what happens to a beyond-cap value on save/load/randomize." The design
answers partially and incorrectly in one place. §6 l.661-666 / §8 #4 (l.730-733): "an
imported state whose value exceeds the current cap is re-clamped to the cap on load
(inward-ratchet-respecting)." But the inward ratchet (§3.1) says a value beyond the cap
that was *legitimately authored under extremeness* must **persist, not snap**
(l.398-404, 462-463). For import to honor that, the loader must know, **per control**,
whether each loaded value was authored under extremeness — but the save records only "the
extremeness setting" (singular, B3). With a single recorded flag and a per-control
ratchet, the loader cannot distinguish "this 0.95 was a deliberate extreme" from "this
0.95 is stale/corrupt," so "inward-ratchet-respecting re-clamp on load" is **not
computable** from the recorded data. Either it snaps legitimate extremes (data loss,
contradicts the ratchet) or it preserves everything (no import safety, contradicts the
guarantee). The design states both safety and preservation as satisfied; they cannot
both hold under the recorded schema. (Depends on B3; ranked MAJOR because the import
slice is sequenced after the cap table and could be redesigned, but as written it is a
contradiction.)

`from_dict` (`body_state.gd:785-797`) also does **no clamping at all** — it copies
verbatim (`:790-792`); the design's claim that loaded scalars are "already clamped at
projection" is true only for what reaches `_project_modifiers`, and that clamp is the
**hard** `[-1,1]`/`[0,1]` range (`:554,563`), never the cap. So there is currently zero
cap enforcement on any load path, and the design supplies no concrete clamp site for it
beyond "re-clamp on load" — same unspecified-mechanism problem as B1, on the import path.

### M2 — The ratchet's "no retroactive snap" + a versioned-caps retune (§3.3) directly conflict, and the conflict resolution is hand-waved.

§3.3 l.460-463: on migration to a new caps version, "a value already beyond the new
cap, if it was legitimately authored under extremeness, persists; only newly-out-of-range
*capped-range* values snap." This needs, per value, the boolean "was this authored under
extremeness" — which (M1, B3) is not stored per control. So the migration rule cannot be
executed as written. Worse, "newly-out-of-range capped-range values snap" is internally
ambiguous: a value that was *within* the old cap but is *outside* the new (lowered) cap
is, by the inward-ratchet definition (l.401-404, "once a value re-enters the capped
range it is bounded going forward"), supposed to be sticky if it never left — but the
migration says it snaps. The two rules give opposite answers for the same value. The
"the snap is visible — never silent" line is the only concrete commitment here; the
actual snap *predicate* is contradictory.

### M3 — "Controls mean what they say" is asserted preserved (§1) but the cap model breaks it exactly as the rejected range-shrink alternative does — the distinction is rhetorical.

§1 l.208-211 rejects input-space range-shrink because "it breaks 'controls mean what
they say,'" then claims v6's caps are different because "the cap defines the control's
*normal* reach and the extremeness gate explicitly extends it." But operationally the
default cap **is** a shrunk input range: dragging outward hard-stops at the cap
(l.392-396), identical felt behavior to range-shrink — the slider says 100 but stops at,
say, 60 until you find and raise a T3 extremeness control. The user who types "+100" in
the mandatory numeric field (§1.3 l.314-317, "clamped to the control's current cap")
gets silently clamped to the cap — the exact "controls don't mean what they say" defect
the design rejected mechanism A to avoid. The rejection of the alternative is therefore
**unjustified given v6 adopts the same observable behavior**; the design should either
own that it accepts bounded-by-default-with-an-unlock (fine) or stop claiming the
property it doesn't have. As written it is a contradiction between §1's rejection
rationale and §3's mechanism.

### M4 — Surfacing the existing belly morphs as a "combined fullness" control re-creates the multi-axis stacking problem the bounds model can't bound (B2), with no per-control cap design for the combination.

§2 l.350-353 proposes "**Belly fullness / forward**" → `torso-scale-depth` +
`measure-waist-circ` "as one combined 'fullness' control." A single UI control driving
two summed morphs is precisely a coupled multi-axis stack — and per facts-belly.md the
"big non-pregnancy belly" recipe is *three* axes summed (`stomach-tone-decr` +
`measure-waist-circ-incr` + `torso-scale-depth-incr`, facts-belly.md l.105-107) plus
`Weight`/`apple` whole-body fat on top. Each is capped independently (§3.1), so a single
"fullness" slider at its cap drives multiple summed morphs, and stacking `Weight` +
`apple` + the belly group composes additively (B2) into the abdomen with no combined
bound. The belly surfacing is correctly a UI task (facts-belly.md verified — all axes
imported, l.126-131), but the design hands the *combination* to "USER render check"
(l.357-358, §8 (b)) without acknowledging that the combined control is exactly the
stacking case B2 shows the caps don't bound. The belly group is where monstrous stacking
will first appear in practice, and the design has no cap mechanism for a control that is
itself a sum.

### M5 — The faceting "subdivision setting" remedy is named but its mechanism is genuinely undecided in a way that affects whether the §8 #8 gate can ever pass on Quest, and the design ships extreme as opt-in BEFORE deciding it.

(Acknowledged open per R6/R10 — attacked only because the *sequencing* is unsound.)
§3.2 l.424-432 offers two forms (bake-time subdivision vs runtime quality tier) and
defers the choice to "§9 R6." But extreme morphs are **reachable as soon as the
extremeness gate ships** (§3.1), and gate #8 (l.751-757) flags faceting whenever an
extreme facets. On Quest the subdivision setting is "off/low" (l.430, 537, 758-759), so
**Quest has no faceting remedy at all** while still allowing opt-in extreme (the gate is
global, B3, so a desktop-authored extreme body imported/replayed on Quest facets with no
lever). The plan "decide bake-time vs runtime" doesn't address that the remedy is
*platform-absent* on the platform that most needs it, while the gate that would catch it
(#9, Quest budget) is itself "gated on an XR/Mobile build existing" (l.758-759) — i.e.
unrunnable today. So the one verification that would catch the unremedied Quest faceting
cannot run, and extreme ships anyway. The resolution plan is missing the
extreme-on-Quest case entirely.

### M6 — Self-intersection demoted to monitoring leaves the no-monsters-by-default GUARANTEE resting on a check that is "feature work to build" with no fallback if it can't meet budget.

(R7 acknowledges it's monitoring + feature work; attacked because the DEFAULT-caps
guarantee depends on it and the plan's budget escape is unsound.) §8 #1 l.712-721: at
default caps, "no self-intersection" is "a PASS/FAIL gate" and "the no-monsters-by-
default acceptance check." But the self-clip itself doesn't exist ("No BVH self-clip
code exists today," l.720-721) and is bounded by "~≤50 ms per body, prototype-verified;
reduce N (rotating seed space) if the window overruns" (l.718-720). Reducing N is a
**direct weakening of the no-monsters guarantee**: the guarantee is "N=10,000 seeds,
no self-intersection" (l.709-712); the escape hatch silently shrinks the sample space
when the check is too slow, so the gate that *defines* the only PASS/FAIL no-monsters
acceptance can be made to pass by testing fewer bodies. A guarantee whose verification's
own fallback is "test less" is not a guarantee. Either the per-body budget is met at
N=10,000 (unproven — "prototype-verified" is aspirational, no code exists) or the gate
quietly degrades. The plan needs a real answer for "what if 10k × narrowphase doesn't fit
the nightly window," not "reduce N."

---

## MINOR

### m1 — Mirror fix (v6 D): the design's premise that v5 "drove only the left arm" is described as a v5 bug, but the CURRENT code already resolves both twins unconditionally (`region_sliders.gd:138-145`), so the D fix is largely re-stating existing behavior as if it were a change. The genuine new work (separating the contralateral-application toggle from resolution, the twin table, the midline guard m3) is real, but the design over-credits itself for "fixing" resolution that `:141-142` already does. Low risk, but the framing hides that the *only* new code is the mirror-application path + twin table; the resolution path needs no change. Verify by reading `resolve_full_names` — it already appends both `l-` and `r-` (`:141-142`), 0 unpaired twins confirmed (291 mods, 61 `l-`, 0 unpaired @ HEAD).

### m2 — §1.3 "build-time assert fails if any `l-` has no `r-` twin" (m6, l.262-263): sound and verified satisfiable today (0 unpaired). But the twin table is built by string-substituting `l-`→`r-` (l.260-262). At least one midline/non-bilateral modifier could contain the literal substring `l-` not at a side position (e.g. inside a token); the substitution + "keep iff twin exists" guard handles false matches by dropping them, but a modifier whose name legitimately contains `l-` mid-token AND happens to have a coincidental `r-` form would mis-pair. Suspected low-probability; would verify by scanning all 291 names for `l-` occurrences not at a side boundary.

### m3 — §5.5 glow ε world-space correction (m-7, l.612-618): `v + n·(ε_world/height_scale())` is correct ONLY under the stated assumption (uniform height scale, overlay a direct skeleton child). The design itself flags (m-C) "a future per-bone/non-uniform scale would break it with no guard." That is honest, but it ships a formula with a known silent-break condition and no assert. Add a build/run assert that `skeleton.scale` is uniform, or the cleanup re-breaks invisibly later. Minor (current state holds: `body_rig.gd:729-731` sets uniform `skeleton.scale = height_scale()`).

### m4 — §5.0 tangent rebake on commit, not during drag: the during-drag tangents "drift as positions move, so normal-mapped detail is slightly off mid-drag" (l.518-520), deferred to a (b) user-gated call. Defensible, but note the drift is worst exactly during the large sculpt drags the creator exists for, and the §8 #7b user gate can only be evaluated after Tier-A skin normals ship (§5.1) — so the acceptability of the core sculpt interaction is gated on a downstream deliverable. Sequencing coupling worth flagging; not a flaw in itself.

### m5 — §8 #1 conflates three jobs in one harness (PASS/FAIL no-monsters gate at default; monitoring at extreme; cap-CONSTANT tuning). Using the same 10k-seed sweep to *tune the constants* and to *gate on the constants* is circular: the cap constants are chosen so the sweep passes, then the sweep passing is cited as the no-monsters guarantee. The guarantee is only as strong as the cap constants the same harness tuned. Acknowledged-ish (R6 "default-cap constants until the sweep runs") but the circularity (tune-to-pass, then pass-as-proof) is not called out.

### m6 — §3.3 "byte-identical baked mesh" across runs/platforms (gate #5, l.734-737) is asserted for the cap clamp because it's "a per-value min/max (no float-order hazard)." True for the clamp, but the *bake* (`bake_morphed_normals`, triangle normal pass + scatter over 14,517 verts, and the new seam-split Lengyel tangent pass §5.0) involves float accumulation whose cross-platform byte-identity is asserted nowhere and is the usual place determinism claims fail. The design narrows the determinism claim to the clamp and lets "byte-identical baked mesh across platforms" ride; that broader claim is unverified. Suspected; would verify by diffing a baked mesh across two platforms (no XR/Mobile build exists, l.758, so currently unverifiable — which is itself the point).

---

## Areas attacked and NOT broken (verified, reported per mandate)

- **Gaze-left-alone (v6 E):** verified. `face_rig.gd:256-258` rotates `BONE_EYE_L/R` via
  `_set_eye_look` from `val_look_dir`; `eye.gdshader:22,61` has `gaze_dir` as a uniform
  defaulting to forward `(0,0,1)` and keys the iris off the model-space normal; driving
  `gaze_dir` from the bone forward WOULD double-count. The "leave gaze alone" decision is
  correct and the double-count rationale is real. No flaw.
- **Belly = surfacing, not authoring (v6 C):** verified against facts-belly.md and
  `region_sliders.gd:60-67` (waist-circ, navel, hip already wired as specs). All cited
  belly axes are real imported targets; this is a UI task. The only attack that lands is
  the *combination* stacking (M4), not the surfacing claim.
- **Bilateral twin completeness:** verified @ HEAD — 291 modifiers, 61 `l-`, 0 unpaired.
  The mirror twin table is buildable; the m6 build-assert is satisfiable today.
- **Pure-sum composition / no per-vertex budget:** verified `detail_library.gd:104`
  (`morphed[ri] += …*weight`); no cumulative bound exists. The design's claim that v6
  adds nothing to the bake hot path is TRUE *for the composition stage* — but that very
  truth is what makes B1/B2 bite (the only place a cap could live, the hot path, is
  deliberately left untouched, so the cap must live in the two scattered clamp sites,
  which v6 doesn't wire).
- **Sculpt drag is modifier-space:** verified `morph_drag.gd:319` returns
  `{full_name: value_delta}`, applied at `character_creator.gd:467` as `cur+delta`
  written verbatim (no re-clamp at apply) — confirms the clamp lives only in
  `decompose_drag` against the build-frozen `rangef`, which is exactly B1.
- **`is_adult_body` predicate exists** (`body_state.gd:451`), single chokepoint as the
  design states (§2 l.364-366). No flaw.
