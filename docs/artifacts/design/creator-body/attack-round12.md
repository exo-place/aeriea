# Attack — round 12 (hostile review of SYNTHESIS.md v12)

Hostile reviewer pass. Only findings that hold up against the actual code/assets @ HEAD are recorded.
Acknowledged open/deferred items with sound plans/seams are NOT ranked as flaws (per the review
contract). The core single-value cap formula (`hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)`) was
re-derived and is not attacked further — it remains sound.

The v12 changes are MA-1 (the DEFAULT CAP RULE / derived intervals), MA-2 (drag-aware held bounds), and
MI-1 (belly references the existing waist slider). MI-1 and MA-1 hold up under re-check. MA-2 does NOT —
it fixes the round-11 trap on the *slider* path but re-opens the identical trap on the *sculpt* path,
which is the very path MA-1 spent its whole effort bringing under the choke.

One finding holds at MAJOR. The rest are MINOR or explicitly-verified-sound.

---

## MAJOR

### MA12-1 — The v12 MA-2 drag-aware held-interval fix is anchored entirely on the SLIDER `drag_started`/`_drag_pending` mechanism, which the SCULPT drag path never triggers — so the exact round-11 MA-2 transient-dip trap is re-introduced on the sculpt path, on the very ~224 uncurated modifiers MA-1 just brought under the choke.

**Locus:** §3.2 step 3 ("DURING an active drag (`_drag_pending[control] == true`, set by `drag_started`
`character_creator.gd:1052-1053,1181`) … `cur_start` … captured in `drag_started` alongside the existing
`_drag_pending[control] = true` write"), the v12 summary MA-2 ("the value captured at `drag_started`, in a
new `_drag_start_value` dict alongside the existing `_drag_pending` write"), gate #1a (iv); vs the actual
sculpt drag bracket at `character_creator.gd:632-648` + the per-frame sculpt apply at
`character_creator.gd:446-475`.

**What the design ties the fix to.** The entire MA-2 held-interval mechanism keys on
`_drag_pending[control] == true`, and the new `_drag_start_value[control] = cur` is written "alongside the
existing `_drag_pending[control] = true` write." Both of those writes exist in exactly two places in the
code: the SLIDER `drag_started` lambdas — `character_creator.gd:1052-1053` (headline) and `:1181` (region).
The design cites precisely those line numbers as the capture site.

**What the sculpt path actually does.** A sculpt drag is a different gesture bracket entirely:
- start: `character_creator.gd:632-644` — on `MOUSE_BUTTON_LEFT` pressed in sculpt mode with a body hit,
  sets `_dragging_morph = true`, `_drag_vertex`, `_drag_hit_pos`, `_drag_accum = {}`. It does NOT set
  `_drag_pending[…]` for any modifier.
- per motion frame: `:660-663` → `_apply_morph_drag` (`:446-475`), which calls `decompose_drag`, gets
  `{full_name: delta}` for MANY modifiers (`:460-466`), and writes each via `cur + delta`
  (`:467-471`), then `_apply_state()`.
- end: `:646-648` → `_end_morph_drag` (`:500`). No `_drag_pending` clear, because none was set.

So during a sculpt drag, `_drag_pending[M]` is `false` for every touched modifier `M`. By the design's
own step-3 rule, a control with `_drag_pending` false is the **"non-drag edit"** branch: *"compute
`[lo, hi]` from `new` immediately, as before"* (§3.2 step 3, third bullet). That is the v10/v11
every-edit recompute — i.e. the round-11 MA-2 behaviour, re-applied per sculpt-motion-frame.

**The trap, reproduced on the sculpt path.** Sculpt writes outward deltas every motion frame. Take a
bidirectional modifier `M` with default `[-0.5, +0.5]`, current ratcheted `cur = +0.9` (loaded from a
user save). The user grabs the surface and, within one continuous sculpt gesture, pulls the region in
(value dips toward `+0.6`) and then back out toward `+0.85`:
- At the `0.6` sample, the choke uses `cur` = the live stored value (no `cur_start` held for sculpt,
  because `_drag_start_value[M]` was never written), and step 3 recomputes
  `[lo, hi] = [min(-0.5, 0.6), max(0.5, 0.6)] = [-0.5, 0.6]`.
- If `M` is bound to a T2/T3 slider (the design's path-1 "sculpt-driven slider SYNC", §3.2 lines
  1034-1037 — "step 4 … writes that slider's bounds + value via `set_value_no_signal(new)`"), the slider's
  `max_value` is set to `0.6`, and the held reach to `0.9` is destroyed. The remainder of the gesture is
  trapped exactly as in round-11 MA-2.
- Even when `M` has NO bound slider (the common case for the ~224 uncurated sculpt-only modifiers — see
  the sub-point below), the *value clamp itself* is broken: step 1's choke reads `cur` = the live stored
  value (now `0.6`), so on the next frame `hi = max(0.5, 0.6) = 0.6` and a request back to `0.85` clamps
  to `0.6`. The held-interval choke fix (§3.2 "The CHOKE itself uses the HELD interval mid-drag") is
  predicated on `cur = cur_start`, and `cur_start` is never captured for sculpt — so the choke falls back
  to the live `cur`, the same per-frame ratchet collapse.

**This is the round-11 MA-2 defect, un-fixed on the sculpt path.** v12's prose claims MA-2 "fixes the
load-bearing case" and that the held bounds apply "for the whole gesture," but the mechanism it specifies
(`_drag_pending` / `drag_started`-captured `cur_start`) is the slider-widget gesture, not the sculpt
gesture. The sculpt gesture has its own bracket (`_dragging_morph`, `_drag_vertex`, `_drag_accum`) that
the design's MA-2 text never references and never hooks. The fix is real for slider drags and absent for
sculpt drags.

**It bites the modifiers MA-1 just added.** MA-1's whole purpose is that sculpt reaches the ~224
uncurated modifiers and they must be capped/ratcheted like the curated ones. So the sculpt path is now a
*first-class* ratcheting write path by v12's own design — which makes the missing held-interval on that
path a genuine coverage hole in the v12 ratchet model, not an edge case. (Pressure-test (2) from the
brief, answered against the code: a sculpt edit touches MANY modifiers at once via `decompose_drag`; under
the specified mechanism NONE of them gets a held interval, because the held interval is written only in
slider `drag_started`.)

**The gate has the same blind spot.** Gate #1a (iv) (§8) drives the transient-dip test through the SLIDER
path only ("`drag_started` then a stream of `value_changed` to `0.6` then back to `0.85`, then
`drag_ended`"). Gate #1a (v) drives a single sculpt apply on an uncurated modifier to assert it is
capped (MA-1), but it is a single apply, NOT a continuous sculpt drag with a transient dip. So no gate
exercises a *continuous sculpt drag* through the ratchet — precisely because the sculpt path has no
`drag_started` to anchor a held interval, the gate as written cannot detect the trap.

**Concrete method to confirm:** `character_creator.gd:632-648` is the sculpt gesture bracket; it sets
`_dragging_morph`, not `_drag_pending`. `_apply_morph_drag` (`:446-475`) runs per motion frame and writes
every decomposed modifier. The design's `cur_start` capture is cited at `:1052-1053,1181`, which are the
slider `drag_started` lambdas only (verified — `grep` for `_drag_pending`/`drag_started` returns only the
slider lambdas at 1052/1055/1181/1182). Therefore `_drag_start_value[M]` is never written for a
sculpt-touched modifier, and step 3's "non-drag edit" branch recomputes bounds from the live mid-drag
`new` every sculpt frame.

**Honest fix direction (not specified by v12):** the held-interval phase signal must be the gesture
bracket, not the slider's `_drag_pending`. For sculpt, capture `_drag_start_value[M] = cur` for each
modifier the first time it is touched within a `_dragging_morph` gesture (in `_apply_morph_drag`, or at
`_dragging_morph = true`), hold it until `_end_morph_drag`, and have both the choke (`cur = cur_start`)
and the bounds recompute use it for the gesture's duration; recompute from the settled value in
`_end_morph_drag`. v12 names none of this — it reuses the slider `_drag_pending` machinery that the sculpt
path does not feed.

---

## MINOR

### MI12-1 — "extremeness change recompute" during an active drag is an un-addressed (if unlikely) interaction; the design lists extremeness-change as a recompute trigger but does not reconcile it with a held interval.

**Locus:** §3.2 step 3 second bullet + the slider-bounds paragraph (§3.2, "recomputed … on
extremeness-change") — bounds recompute on extremeness-change is listed unconditionally, in parallel with
the held-during-drag rule.

If the global extremeness slider is moved while a modifier drag is somehow in progress, the design says
bounds recompute from the settled `new` on extremeness-change — which would override the held interval
mid-gesture and could re-introduce a collapse. In practice the two are separate widgets and concurrent
manipulation is hard to reach with a single pointer, so this is MINOR and suspected rather than
demonstrated. **Suspected; would verify by** checking whether extremeness is reachable via keyboard/second
input device while `_dragging_morph`/`_drag_pending` is set; if not reachable concurrently, this is a
non-issue and should be stated as such rather than left as an unconditional trigger that contradicts the
held-during-drag rule.

---

## Load-bearing v12 areas attacked and NOT broken (re-verified against code/assets @ HEAD)

- **MA-1 — DERIVED interval rule produces a sane cap for EVERY non-curated modifier (pressure-test (1)).**
  Re-checked the registry directly: `assets/body/modifier_registry.json` has 291 modifiers — 251
  bidirectional (range EXACTLY `[-1,1]`, default 0), 29 unipolar (range EXACTLY `[0,1]`, default 0), 11
  macro (excluded from sculpt via `KIND_MACRO` skip at `morph_drag.gd:148`). There are NO odd ranges and NO
  nonzero non-macro defaults (verified: zero bidirectional outside `[-1,1]`, zero unipolar with min≠0, zero
  non-macro with default≠0). So the derived interval `[neutral−f·R, neutral+f·R]` clamped to the hard range
  yields `[-f, +f]` for every bidirectional (symmetric, contains 0) and `[0, f]` for every unipolar (floor
  pinned to neutral 0). **Gate #11b's `neutral ∈ [a,b]` holds BY CONSTRUCTION for every derived interval** —
  the construction proof is valid because the registry has no pathological range/default. The "bidirectional,
  unipolar, odd registry ranges" pressure-test finds no break: there are no odd ranges to break on. MA-1's
  derivation is sound.

- **MA-1 — sculpt reaches the ~224 uncurated modifiers (the premise) is TRUE and the total-function fix
  closes the "undefined cap" hole.** `build_accel` (`morph_drag.gd:138`) iterates
  `registry.get("modifiers", [])`, skips only `KIND_MACRO` (`:148`) and modifiers whose +pole target is not
  in the library (`:154-155`), and emits a candidate per moved vertex — so a sculpt drag can write any
  imported non-macro detail modifier. The DEFAULT CAP RULE making `cap(·)` total (authored-or-derived) does
  close the "no interval ⇒ uncapped" hole at the *value-definition* level. (The remaining defect is
  MA12-1: the interval exists, but it is not HELD across a sculpt gesture.)

- **Pressure-test (3) — any modifier reachable by a write path with NO interval?** No. With MA-1's total
  function, every reachable control has an interval (authored or derived). The gap is not a missing
  interval; it is a missing HELD interval during a sculpt gesture (MA12-1).

- **MI-1 (belly waist-circ) is genuinely resolved in v12.** §2 now references the existing `:63` "waist"
  slider for belly girth and adds only the net-new `torso/torso-scale-depth`; the anti-duplicate rule is
  extended to `waist-circ` ("No modifier is driven by two controls"). Verified `region_sliders.gd:63` is
  `["measure/measure-waist-circ-decr|incr", "waist", "narrow", "wide"]` and `torso-scale-depth` is not in
  `region_sliders.gd` today. Round-11 MI-1 is correctly closed; no new duplicate introduced.

- **MA-2 on the SLIDER path is sound.** For slider drags, `drag_started` (`:1052-1053,1181`) does fire and
  `_drag_pending`/`_drag_start_value` would be set, so the held interval works as designed and the
  round-11 MA-2 slider trap is genuinely fixed. The defect is strictly the sculpt path's absence from this
  mechanism (MA12-1). The slider-path no-re-fire ordering (bounds-first-then-`set_value_no_signal`) is
  unchanged and the Godot clamp-and-emit hazard it guards is real (confirmed by `options_menu.gd` comment,
  per round 11).

- **Core cap formula** — unchanged from v11; re-derived for the window (masculinity `[20,80]`), sign-flip
  (`cur=0.9,b=0.5`), and beyond-cap persistence. Per-pole independence holds. Not broken.

- **Erase-at-neutral + `neutral∈[a,b]` invariant (curated controls)** — `_set_modifier` erases `|v|<1e-6`
  (`character_creator.gd:1209-1214`); absent→neutral read `modifiers.get(fn,0.0)` reproduces `cur` iff
  `neutral∈[a,b]`. Sound for the curated + derived controls (the derived ones inherit it by construction,
  per the registry check above).

- **Restore/load raw bypass** — every restore path (`_restore_current` `:1315-1331`,
  `_restore_modifier_sliders` `:1232-1238`) sets `slider.value = v` today, which would re-fire the capped
  callback; the `set_value_no_signal` raw-bypass fix is genuinely required and correctly motivated.
  `_suspend_commit` gates only the commit (`:1320`), not the callback — verified. Not broken.

- **First-build vs deferred (§10.1)** — the deferred items (combination-plausibility §3.4, Tier-B baker
  §5.1, subdivision cost, procedural-iris taste verdict §5.2, Quest costs, cornea parallax, self-intersection
  monitoring, the default-interval constants + fraction `f` pending the §8 #1b taste sweep) are honestly
  flagged with stated seams; none leaves a first-build item broken. The `f` constant and interval shapes
  are an acknowledged-open authoring/tuning item with a sound seam (caps asset + pure function) — NOT a
  flaw per the contract. MA12-1 is NOT a deferral; it is a specified-but-mis-targeted mechanism.

---

## Summary

- **MA12-1 (MAJOR):** v12's drag-aware held-interval mechanism (MA-2) is anchored on the slider
  `drag_started`/`_drag_pending` gesture and never wired to the sculpt gesture bracket
  (`_dragging_morph`/`_drag_vertex`), so the round-11 MA-2 transient-dip ratchet trap is re-introduced on
  the sculpt path — the exact path MA-1 made a first-class capped/ratcheting write path. The gate (#1a iv/v)
  shares the blind spot (tests the slider continuous-drag and a single sculpt apply, never a continuous
  sculpt drag with a transient dip).
- **MI12-1 (MINOR):** extremeness-change is listed as an unconditional bounds-recompute trigger in parallel
  with the held-during-drag rule, unreconciled for the (unlikely) concurrent case; suspected, not
  demonstrated.
- MA-1's derived-interval rule, MI-1's belly fix, MA-2 on the slider path, and the core formula are
  re-verified sound against the actual registry and code.
