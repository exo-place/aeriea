# Attack — round 7 (hostile review of SYNTHESIS.md v7)

Hostile reviewer pass. Sole job: break the design. Strengths NOT listed; no
approve/ready verdict given. Every factual attack is grounded in a citation; suspicions
are labeled. Acknowledged open/deferred items WITH sound plans are NOT counted as flaws
unless they break a first-build item or the plan/seam is unsound.

Re-verification was done against actual code/assets @ HEAD, not the design's own
"verified/resolved/owned" claims.

---

## BLOCKER

### B7-1 — The v7 clamp formula `new = min(req, max(cur, c))` does NOT clamp bidirectional axes — it leaves ~46 of 56 curated controls' inward/decr pole completely uncapped.

This is the single load-bearing mechanism of the entire v7 "bounds finalized" claim
(§3.2, the formula at SYNTHESIS.md line 445), and it is wrong for the dominant control
type in this body system.

**The facts:**
- Region detail axes are stored as ONE SIGNED scalar in `[-1, 1]`, neutral = 0, where
  BOTH poles are "outward"/extreme: "v<0 drives the min/decr pole by |v|; v>0 drives the
  max/incr pole by v" (`region_sliders.gd:16-19`).
- **46 of the 56 curated sliders are bidirectional** signed axes (counted: every spec
  containing `|` — `-decr|incr`, `-down|up`, `-in|out`, `-horiz`, etc.,
  `region_sliders.gd:40-` GROUPS). The flagship size control is itself bidirectional:
  `breast/breast-volume-vert-down|up` (`region_sliders.gd:42`), stored as a single
  signed float.
- A single bidirectional value is one entry in `BodyState.modifiers` (`{full_name:
  float}`, `body_state.gd:790-792`), written at the apply sites as a raw signed float
  (`character_creator.gd:466,470`; `_set_modifier` `:1209-1214`).

**The break:** `cap(control, extremeness)` returns a SINGLE value `c` and the clamp is a
single `min`. For a bidirectional axis, "extreme" is `|value|` large in EITHER direction.
Execute the formula as written for the decr/small/flat/low pole:
- User requests `req = -1.0` (fully toward the decr/extreme pole) at extremeness 0.
- `new = min(-1.0, max(cur, c))`. With `cur=0`, `c>0` (any positive default cap), this is
  `min(-1.0, c) = -1.0`.
- The value lands at the HARD registry limit `-1.0`, fully unclamped. The cap did nothing.

So at extremeness 0 — the "no-monster-by-DEFAULT" mode — a player can drive breast volume,
waist circumference, hip scale, stomach tone, buttocks volume, torso V-shape, etc. to their
full negative extreme with NO cap whatsoever. The "default mode stays plausible via
conservative per-control default caps" claim (§3, §3.4) is FALSE for ~82% of the curated
controls as the formula is literally written.

**Why the design's escape hatch fails:** §3.2 parenthesizes "(for an increasing axis;
mirror for decreasing / per polarity)" (SYNTHESIS.md line 442). But a bidirectional axis is
not "an increasing axis" OR "a decreasing axis" that you pick one mirror for — it is ONE
stored signed scalar that must be two-sided-clamped to `[-c_neg, +c_pos]` with TWO caps and
TWO comparisons. The stated state model says "one global `extremeness` scalar" and a `cap(control,
extremeness)` returning a single value (§3.1, §3.2) — there is no per-polarity cap pair in the
model, and the formula has no lower-bound term. The prompt's exact question — does the formula
deliver "hard clamp outward" for a `|decr|incr|` axis where "outward is both directions from
neutral" — answers NO. The formula handles exactly one of the two outward directions.

This is a genuine DESIGN FLAW, not an acknowledged open risk: the design claims the bounds
model is "FINALIZED" and "RESOLVED" (§3 header, R6) and presents this exact formula as "the
precise model the prompt specifies" (§3.2 line 459). It is named as a concrete executable
method but the method is incorrect for the system's primary axis type. The fix is not a
re-derivation away (clamp `|new|` to a per-polarity cap), but the design as written, executed
literally, ships an uncapped negative pole on 46 controls.

---

## MAJOR

### B7-2 — The "exactly TWO physical write sites" claim omits the headline-axis write path; the six headline axes (the entire T1 surface) are NOT covered by the input-layer clamp.

§3.2 (line 435): "There are two physical write sites (slider/numeric write; sculpt apply at
`character_creator.gd:460-471`), both calling the SAME clamp helper." §10.1 first-build lists
"the single input-layer clamp helper at the two write sites."

**The facts:** the six headline axes — `age_years`, `height_cm`, `masculinity`, `muscle`,
`weight`, `proportions` — are NOT stored in `modifiers` at all. They are direct fields on
`BodyState` (`from_dict` `body_state.gd:787-792`; `_format_value` reads `_body_state.get(field)`
`:1242`). They are written through a THIRD, distinct path: the headline slider callback
`_body_state.set(field, v)` (`character_creator.gd:1047`) and the history-restore
`_body_state.set(field, v)` (`:1323`). Neither of these is one of the two named sites
(460-471 sculpt, or `_set_modifier`/the numeric write into `modifiers`).

**The break:** the design's own §1.1/§1.2 make the six headline axes the T1 surface and §1.3
gives them mandatory numeric entry "Clamped to the control's current cap `cap(control,
extremeness)`" (line 339). But the actual write path for those axes (`set(field,...)`) is
not enumerated among the clamp sites, and the headline axes don't live in `modifiers` where the
clamp helper operates. As scoped, the input-layer clamp catches modifier-space writes only and
SILENTLY MISSES the headline axes — so "172 cm" / extreme height / extreme masculinity have no
cap enforcement. The clamp-site enumeration that the design presents as the round-6-B1 fix
("one cap site, fed the live derived cap") is incomplete: it is at least THREE write sites
(sculpt, modifier-slider/numeric, headline `set(field)`), and the headline path operates on a
different storage location with a different value convention (natural units / 0–100, not the
`[-1,1]` modifier convention the `min`/`max` formula assumes).

This directly contradicts the prompt's clamp-completeness question ("does the clamp site catch
ALL write paths"): it does not. Archetype-load and history-restore also write both fields
(`:1322-1323`) and modifiers (`:1327`) by whole-map replacement — and the design intends those
to NOT clamp (raw storage), which is fine — but the live-EDIT headline path is uncapped, which is
not.

### B7-3 — First-build gate #1's "no self-intersection" assertion depends on a BVH self-clip that the design itself says does not exist and defers as monitoring-only feature work.

§8 #1 (first-build per §10.1's "objective quality gates (§8 (a))... the per-control default-cap
plausibility sweep (#1)") asserts, clause (b): each default cap, per-control, produces "no
self-intersection" (SYNTHESIS.md line 811-813). §8 #1 also: "Self-clip is FEATURE WORK,
monitoring-only... No BVH self-clip code exists today" (lines 816-818).

**The facts:** verified — there is no self-intersection / BVH / spatial-hash self-clip code in
the repo (`grep -rin "self.inter\|self_clip\|spatial_hash" scripts/ tests/` returns nothing;
the only BVH hits are motion-capture retarget and a picker comment, `cpu_accel_picker.gd:10-15`,
`body_rig.gd:1270`). §3.6/R8/§10.2 deferral text places "Self-intersection ENFORCEMENT" and the
"BVH/spatial-hash self-clip... built as a nightly report" outside the first build.

**The break:** the FIRST-BUILD gate #1 cannot run its no-self-intersection clause without the
BVH that the SAME design defers. Either gate #1 is not actually runnable in the first build
(contradicting §10.1's listing it as a shipped objective gate), or the BVH is implicitly
first-build (contradicting §3.6/R8/§10.2 deferral). This is a §10 first-build-vs-deferred
self-consistency failure of the exact kind the prompt flags: a FIRST BUILD item (gate #1)
depends on a DEFERRED item (the self-clip BVH). The design's claim that "the deferred items are
each named with their hook/seam so none is silently dropped" (line 1016) does not resolve the
ordering: the hook being named doesn't make the first-build gate runnable.

(Note: the per-control AABB-bounds and clamp-held clauses of gate #1 ARE runnable without a BVH;
only the no-self-intersection clause has the dependency. But the design lists "no self-intersection"
as a co-equal assertion of the first-build gate, not as a deferred sub-clause.)

---

## MINOR

### m7-1 — The dihedral faceting metric (gate #8a, first-build) is net-new with zero existing implementation; the design presents it as a shippable first-build objective gate without flagging it as unbuilt.

Verified: no dihedral/edge-angle metric code exists (`grep -rin "dihedral\|facet" scripts/ tests/`
finds only an unrelated `face_expression_test`). §10.1 lists "dihedral faceting metric (#8a)" as
a first-build objective gate alongside genuinely-existing-mostly gates (proxy follow #2 has a
passing test; persistence round-trip #4 has existing read-side). The dihedral metric is
honest-to-build feature work, but it is grouped with near-existing gates as if comparable in cost.
Not a contradiction (the metric CAN be built first-build and is described concretely), so MINOR —
but the §10 cut understates that several "objective gates" listed as first-build are net-new
harnesses (dihedral #8a, the N=10,000 sweep #1, byte-equality determinism #5 against a caps asset
that does not yet exist — `assets/body/caps*` is absent).

### m7-2 — §0 records the breast volume counts as "369/244" but the asset is down=244, up=369; the design's directional reading is reversed.

`base_body_detail.index.json:159-160`: `breast-volume-vert-down` count **244**,
`breast-volume-vert-up` count **369**. SYNTHESIS.md §0 (line 119) and §4 (line 577) write
"count 369/244" listing down|up in that order, i.e. down=369/up=244 — reversed. Harmless to the
"both live (count>0)" conclusion, but it is a factual mis-cite in a doc that elsewhere leans hard
on "facts govern" and exact counts; an executor trusting it would mislabel which pole is the
denser target. MINOR (cosmetic mis-cite, not a logic flaw).

### m7-3 — "Randomize samples within `cap(·, extremeness)`" inherits B7-1: for bidirectional axes, bounded randomize will also be unbounded on the negative pole.

§1.3 / §3.3: "Randomize... samples within `cap(·, current extremeness)`... at extremeness 0 it
samples within default caps, so randomize NEVER produces an extreme body." Since the cap mechanism
itself (B7-1) doesn't bound the negative pole of the 46 bidirectional axes, a bounded seeded
randomize built to "sample within `cap`" using the single-value `cap` would draw arbitrarily-negative
extremes on those axes. (No randomize code exists yet — `grep andom scripts/body/character_creator.gd`
is empty — so this is a forward consequence of B7-1, not an independent defect. Downgraded to MINOR /
consequence-of-B7-1.)

---

## Areas attacked and could NOT break (with what was verified)

- **Gaze double-count claim (§5.2, R3).** Verified: the eye shader keys the iris off
  `v_model_normal` (model-space normal, `eye.gdshader:56,60`) vs the constant `gaze_dir` uniform
  (default `(0,0,1)`, `eye.gdshader:22`). The eye bones rotate via `_set_eye_look(BONE_EYE_L/R, ...)`
  driven by `val_look_dir` (`face_rig.gd:256-258,103-104,290`), and the skinned eyeball carries its
  model-space normals. So the geometry already rotates; driving `gaze_dir` from the bone would indeed
  double-count. The "leave gaze alone" decision holds — could not break it.

- **Breast macro is dead; volume axis is live (§0, §4).** Could not break: both volume targets have
  `count` > 0 (`base_body_detail.index.json:159-160`), so decision (b) binds a live axis. (The
  bidirectional-clamp flaw B7-1 attacks the BOUNDS on this axis, not its liveness.)

- **Sculpt apply site is modifier-space, cap-able in principle (§1.3, §3.2).** Verified: the apply
  site writes `cur + delta` as a raw scalar with no clamp present today (`character_creator.gd:466,470`),
  so the design's claim that a clamp can be inserted at this single site is structurally true — the
  site exists and is the funnel for the sculpt path. (The flaw is the FORMULA used there, B7-1, and the
  MISSING headline site, B7-2, not the existence of this site.)

- **Tongue re-seat = asset re-bake (§5.6, R14).** Could not break: consistent with `new-defects.md` #1
  and the proxy build being an offline-generated asset; the design names the cost honestly as a re-bake,
  not a runtime edit. Acknowledged-cost, sound.

- **Load does NOT re-clamp; raw storage round-trips (§3.3, §6).** Verified: `from_dict` copies modifier
  values and headline fields verbatim (`body_state.gd:787-797`); projection-time hard-range clamping is
  separate (`_project_modifiers`). The design's "load never re-clamps, beyond-cap persists" is consistent
  with the code. Could not break the round-trip/no-snap claim itself. (The single global extremeness
  scalar round-tripping trivially is also sound — but see B7-1/B7-2 for whether the cap it feeds is
  correct/complete.)

- **Combination-plausibility deferral (§3.4, R7) and Quest extreme-faceting limit (§3.6, R9).** These are
  honestly-flagged DEFERRED/accepted limits with reserved seams; per the prompt's instruction they are
  NOT ranked as flaws. The "sum of caps prevents monstrosity" removal is the correct call (composition is
  pure-sum, `detail_library.gd:104` — verified the design's §0 claim). Did not attack as a flaw.
