# Attack — round 14 (hostile review of SYNTHESIS.md v14)

Hostile reviewer pass against the actual code/assets @ HEAD. Only findings that hold up against the real
code are recorded. Acknowledged open/deferred items with sound seams (default-interval constants + `f`;
combination-plausibility; Tier-B baker; subdivision cost; procedural-iris taste; Quest costs;
self-intersection known limit) are NOT ranked as flaws, per the review contract.

The core single-value cap formula (`hi=max(b,cur); lo=min(a,cur); new=clamp(req,lo,hi)`) is unchanged from
v9–v13 and is not re-attacked — re-derived sound across rounds 9/10/11 and traced again here for the
per-pole / sign-flip / beyond-cap-persist cases. The v14 changes are MA13-1 (the choke-capture invariant —
held-interval capture moved INTO `apply_capped`, fired lazily on each control's first touch within a
gesture, replacing the per-path enumeration) and MI13-1 (gesture-end recompute is the full all-controls
bounds sweep when extremeness was deferred). MA13-1 genuinely closes the round-13 mirror-twin hole and the
whole enumeration class for the writes that flow through the choke. MI13-1 holds — its no-clamp-gap argument
(the choke always reads live `cap(control, extremeness)`) is sound against the code.

**One finding holds at MAJOR**, and it is in EXACTLY the class the prompt's concern (4) names — the
interaction of the held-interval map with the raw restore/load bypass. v14 hardened the bypass so it never
CAPTURES (true), but left the symmetric case unaddressed: a raw restore that fires **mid-gesture** does not
clear (or invalidate) the choke's live held-interval map.

---

## MAJOR

### MA14-1 — A mid-gesture raw RESTORE (undo / redo, reachable by keyboard while a mouse drag is held) replaces `_body_state.modifiers` wholesale but neither ends the gesture nor clears the choke's `_drag_start_value` held-interval map. The gesture then continues clamping against a STALE `cur_start`, so a ratchet ceiling that the restore should have reset survives — and the drag commits a garbled node at release.

**Locus.** v14 specifies the held-interval map is "cleared at gesture end" and the ONLY clear sites are
the gesture-end handlers (`SYNTHESIS.md:1050-1057,1064`: "the held-interval MAP is cleared at gesture end",
clear on `drag_ended` / `_end_morph_drag`). The restore/load paths are path 6
(`SYNTHESIS.md:1170-1175`) — raw write + `set_value_no_signal`, by design they do NOT touch the choke or
its map. Nothing in v14 clears or invalidates `_drag_start_value` on a restore.

**The interaction is genuinely concurrent and reachable (verified in code, not hypothetical).**
- A sculpt drag is bracketed by `_dragging_morph = true` (set on left-press-with-hit,
  `character_creator.gd:639-644`) through `_end_morph_drag` (left-RELEASE only, `:647-648`). Per-frame
  motion runs `_apply_morph_drag` (`:660-663`). The bracket ends ONLY on mouse-button release.
- Undo/redo are KEYBOARD events handled in `_unhandled_input`: `Ctrl+Z` → `_do_undo()`, `Ctrl+Shift+Z` →
  `_do_redo()` (`character_creator.gd:576-583`), each funnelling to `_restore_current()`
  (`:1299-1311,1315-1331`).
- Keyboard and mouse-button state are independent: a user can hold left-mouse mid-sculpt and press
  `Ctrl+Z`. The `InputEventKey` reaches `_unhandled_input` while `_dragging_morph` is still `true`.
- `_restore_current` (`:1315-1331`) sets `_suspend_commit = true`, rewrites the headline fields
  (`:1323`), **replaces `_body_state.modifiers` wholesale** (`:1327` `_body_state.modifiers =
  bs.modifiers.duplicate()`), re-syncs widgets, `_apply_state()`, then `_suspend_commit = false`. It
  does NOT reset `_dragging_morph`, `_drag_vertex`, `_drag_accum`, or (under v14) the choke's
  `_drag_start_value`.

**The defect, traced.** Pre-gesture, a touched modifier `M` is ratcheted to `cur=0.9` (default
`[-0.5,0.5]`). The sculpt drag's first frame captures `_drag_start_value[M] = 0.9` (the v14 first-touch
capture), so the held interval is `[-0.5, 0.9]`. Mid-drag the user presses `Ctrl+Z`; `_restore_current`
replaces `_body_state.modifiers` with a prior node where `M = 0.0` (un-ratcheted). The gesture is still
live; `_drag_start_value[M]` still holds `0.9`. The next motion frame's `apply_capped(M, 0.0 + delta)`
clamps against the held `[-0.5, 0.9]` — admitting the drag back up toward `0.9`, a ratchet the restored
state had explicitly removed. The stale held interval is the choke's source of truth until
`_end_morph_drag` clears it, so the restore's reset of the ratchet is silently overridden for the rest of
the gesture. (`_drag_accum` is likewise stale, so the gesture's commit label and committed delta at
release are computed against a base the restore changed — a garbled history node.)

**Why this is the prompt's concern (4), not a stretch.** v14's hardening of the bypass is one-directional:
it guarantees the restore path does not CAPTURE into the map (correct — `set_value_no_signal` bypasses
`value_changed`, so `apply_capped` never runs, so no first-touch capture fires; verified). But the held-
interval map is gesture-scoped MUTABLE STATE that a raw restore can desynchronize from the model WITHOUT
ending the gesture. The design carefully built a deferred-recompute rule for the symmetric extremeness-
change-mid-gesture conflict (MI12-1, `SYNTHESIS.md:1216-1230`) — explicitly declining to rely on the
inputs being unreachable concurrently — yet the structurally identical restore-mid-gesture conflict gets
no rule at all. The asymmetry is the gap: extremeness-mid-gesture is handled by construction; restore-mid-
gesture is not mentioned.

**It is not purely a v14 artifact, but v14 makes it materially worse and owns the invariant it breaks.**
The underlying mid-drag-undo concurrency already corrupts `_drag_accum` in TODAY's code (a pre-existing
hazard). But v14 introduces `_drag_start_value` as a NEW piece of gesture-scoped state whose entire
correctness rests on "cleared at gesture end," and a mid-gesture restore violates that premise on a path
the design's own concern-(4) framing flags. The invariant "any control written through `apply_capped`
during a gesture uses a held interval captured at its first touch" is true, but the held interval is no
longer a faithful pre-gesture reference once a restore has replaced the model underneath it.

**Honest fix direction (not specified by v14).** Treat a restore/load as a hard gesture boundary: if a
restore fires while `_in_sculpt` or any `_drag_pending` is true, END the active gesture first (clear
`_drag_start_value`, `_drag_accum`, `_dragging_morph`/`_drag_pending`) before the raw write — OR suppress
undo/redo while a gesture is active. The same rule the design used for extremeness-mid-gesture (defer /
bracket against the gesture lifecycle) applies; v14 simply didn't extend it to the restore trigger.

---

## MINOR

### MI14-1 — A bilateral region slider drives TWO controls (L and R) but is ONE widget; under the v14 step-4 protocol each resolved name computes and writes its OWN `[lo,hi]` to the SAME slider, so the displayed bounds are whichever resolved name is processed LAST. If L and R have diverged (asymmetric body), the slider thumb range can exceed one side's true held cap. Pre-v14 and arguably out of scope, but v14's "thumb cannot pass the live cap / gating is VISIBLE at the slider" property does not hold for this case.

**Locus.** `region_sliders.gd:136-145` (`resolve_full_names` → 1 or 2 full_names);
`character_creator.gd:1168-1186` (one `HSlider` per spec, value read from `full_names[0]` ONLY at
`:1172`); `SYNTHESIS.md:599-604` (the §1.3 slider path runs the §3.2 protocol "for each resolved name",
each setting "the slider's `min_value`/`max_value`").

**Why it holds.** A bilateral slider drives L and R with the SAME `req` (resolution, not mirror), so in the
common SYMMETRIC case `cur_L == cur_R` and their held intervals coincide — no issue. Divergence is
reachable, though: a mirror-OFF asymmetric sculpt (`SYNTHESIS.md:588-590`) or an asymmetric imported user
save (`§3.3` beyond-cap persists) can leave `cur_L != cur_R`. The v14 protocol then computes
`[min(a,cur_start_L), max(b,cur_start_L)]` for L and `[…cur_start_R…]` for R and writes BOTH to the single
slider; the later write wins. If R was ratcheted to `0.9` and L sits at `0.3`, the slider shows bounds up
to `0.9`, but `apply_capped(L, …)` clamps L to `[-0.5,0.5]` — the thumb can travel to `0.9` while L's
stored value cannot, i.e. the exact thumb/value desync the protocol claims to kill, for this case.

**Why MINOR / scoped.** The bilateral *slider* cannot represent two diverged values regardless of the cap
model — it reads only `full_names[0]` at load (`:1172`), a limitation that predates v14 and predates the
entire cap mechanism. The T2/T3 region slider is the SYMMETRIC control by definition; asymmetry lives in
the sculpt / mirror-OFF domain, where each control has its own widget (or none) and the per-control held
interval is correct. So the v14 invariant itself (per-control capture) is sound; only the SHARED widget's
displayed bounds are ambiguous for a state the bilateral slider was never designed to represent. Worth a
one-line acknowledgement (e.g. a bilateral slider uses the tighter of the two held intervals, or is hidden
/ split when its two sides diverge), not a blocker.

---

## Pressure-test of the v14 choke-capture invariant — the four prompt concerns, traced against code

**(1) Any write reaching the model/cap WITHOUT going through `apply_capped` during a gesture?** NO bypass
found among the live paths. The complete set of model mutators in `character_creator.gd` is: sculpt
(`:466-470`), headline slider (`:1047`), region `_set_modifier` (`:1212-1214`), and restore (`:1323,1327`)
(grep-verified — no other `_body_state.modifiers[...]` / `_body_state.set(field,...)` sites). The three
LIVE ones are routed through `apply_capped` by the v14 design (§3.2 paths 1–5); restore is the raw bypass.
There is no fourth live mutator and no live write that skips the choke. (The numeric-entry and randomize
paths the design routes through the choke do not exist in the code yet — `grep` for `LineEdit` /
`text_submitted` / `randomize` is empty — but they are honestly named as NET-NEW first-build work, not
claimed-existing, so this is not a false-against-code claim.) Clean.

**(2) Well-defined gesture boundary for EVERY entry path, incl. a discrete numeric/headline write and a
randomize-of-many?** Each holds:
- Slider drag: `drag_started`/`drag_ended` set/clear `_drag_pending[field|spec_name]`
  (`:1052-1056,1181-1183`) — keyed by distinct namespaces (headline fields `age_years`… vs region stems
  `l-upperarm-muscle` / `stomach/...`; verified no key collision), so the shared `_drag_pending` dict is
  unambiguous.
- Sculpt drag: `_dragging_morph` press→`_end_morph_drag` release (`:639-648,500`). Clear bracket.
- Single discrete write (keyboard step / click / numeric / one randomize sample): the design defines it as
  a degenerate one-write gesture where capture and end coincide in the one `apply_capped` call
  (`SYNTHESIS.md:1060-1068`). Correct: a region/headline `value_changed` with `_drag_pending` false is
  exactly this (`character_creator.gd:1049,1179`), no stream to dip through.
- Randomize-of-many: the design treats EACH sampled value as its own one-write gesture
  (`SYNTHESIS.md:1061,1065 "single randomize sample"`, path 5 `:1165-1166`). Since randomize writes each
  control EXACTLY ONCE, `cur_start == cur` and recompute-from-`new` is correct per control; there is no
  transient-dip surface within a randomize. Self-consistent. Not a flaw.

**(3) Can first-touch capture ever capture a WRONG `cur`?** Not on the traced paths:
- A control written twice in one frame: within `_apply_morph_drag` the per-frame `deltas` is a Dictionary
  keyed by full_name (`:465`), so each `M` is written once per frame; the §1.3 mirror writes `twin(M)`
  once per frame. No single control is written twice in one frame, so no double-capture races.
- Mid-transition value: round-13 already verified (and re-confirmed here) that on the FIRST frame the live
  `_body_state.modifiers` passed to `decompose_drag` (`:460-462`) equals the pre-gesture state, so the
  first-touch `cur_start` is the true pre-gesture value for directly-touched and late-entering modifiers
  alike. The mirror twin is captured on ITS first `apply_capped(twin(M),…)`, which (mirror runs in the
  same frame, after `M`'s write but on `twin(M)`'s own untouched stored value) reads `twin(M)`'s
  pre-gesture value. Correct.
- The ONE place capture reads a wrong reference is MA14-1: a mid-gesture restore replaces the model after
  capture, leaving `cur_start` stale. That is the restore interaction, ranked above — not a first-frame
  capture bug.

**(4) Interaction with the raw restore/load bypass (which must NOT capture)?** The bypass correctly does
NOT capture (`set_value_no_signal` → no `value_changed` → no `apply_capped` → no first-touch capture;
verified). The remaining gap is the reverse direction — a restore firing MID-gesture leaves the map
populated and stale (MA14-1, MAJOR). When NO gesture is active (the common restore case), the map is empty
(cleared at the prior gesture-end), so restore is clean — confirmed.

---

## Load-bearing v14 areas attacked and NOT broken (re-verified against code/assets @ HEAD)

- **MA13-1 (the round-13 mirror-twin hole) is genuinely closed by the choke-capture invariant.** Traced a
  mirror-ON one-sided drag of `M` with a pre-ratcheted twin `T=twin(M)` (`cur_T=0.9`): the §1.3 mirror step
  calls `apply_capped(T, …)` per frame (`SYNTHESIS.md:601-602,609-610`), so `T` is captured on its OWN
  first touch through the choke (`:1033-1039`) exactly like a directly-touched control — no mirror-side
  capture code, no enumeration. A transient dip on `T` no longer collapses its ratchet. The gate's iv-d
  assert (`:1667-1674`) exercises precisely this. Sound.
- **The "capture inside the choke covers every path" claim holds for all paths that reach the choke** —
  directly-touched slider control, sculpt-decomposed modifier, mirror twin, headline field, numeric,
  randomize sample. Verified there is no live write path that reaches the model without reaching the choke
  (concern 1 above). A future cascaded/derived write would be covered automatically iff it goes through
  `apply_capped` — the design's stated mechanism.
- **MI13-1 (full all-controls gesture-end sweep) has no interim clamp gap.** The choke (step 1) reads live
  `cap(control, extremeness)` at clamp time (`SYNTHESIS.md:1239-1244`), so any edit between a deferred
  extremeness change and the gesture-end sweep is already clamped against the new extremeness; only
  non-touched WIDGET bounds lag one sweep, refreshed by the gesture-end full sweep. Display refresh, not a
  clamp correction. Sound.
- **MI12-1 deferred extremeness recompute** — re-verified: deferral triggers only under `_in_sculpt` /
  `_drag_pending` (`:1219-1221`); with no gesture the change is the immediate all-controls recompute. No
  held interval can exist with no gesture active (map cleared at gesture-end). Sound.
- **Core cap formula** — per-pole independence, window axes (masculinity `[20,80]`), beyond-cap persistence
  and free reduction, no sign-flip across neutral — re-derived; unchanged and sound.
- **Restore citations accurate.** `_restore_current` at `:1315-1331` sets `slider.value = v` (`:1324`,
  `:1237` region) which WOULD re-fire the capped callback — so the `set_value_no_signal` raw-bypass is
  genuinely required and correctly motivated (paths 6/7/7a).
- **`_set_modifier` erase-at-`|v|<1e-6`** at `:1209-1214` matches the design; the `neutral ∈ [a,b]`
  invariant (gate #11b) makes the absent→neutral read lossless. Sound.
- **Bilateral resolution always-on** (`region_sliders.gd:136-145`) drives both L and R regardless of the
  mirror toggle — matches §1.3; gate #10 asserts it. (The shared-widget-display ambiguity for DIVERGED
  L/R is MI14-1, scoped above.)
- **Sculpt gesture bracket / motion / end citations** (`:639-648`, `:660-663`, `:500-516`) accurate.
- **Verified-requirement cross-check.** `new-defects.md` items 1 (tongue position), 2 (glow stuck at
  neutral), 3 (glow clips through body) are each addressed: glow-neutral and glow-clip in §5.5 (refresh from
  morphed surface; world-space ε outward offset + uniform-scale assert, R14), tongue re-seat as an asset
  re-bake in §5.6 / R14. `diagnosis/*` items relevant to the creator (sculpt-on-neutral-mesh B2, default
  hair cap, camera) are folded into §5.5 / §0 / §5.4. No silently-dropped verified requirement found.
- **First-build → deferred dependency.** Re-scanned §10.1 against §10.2: gate #1 no longer asserts
  self-intersection (deferred); gate #8 ships the dihedral metric and only FLAGS faceting (subdivision
  remedy deferred); Tier-A skin depends only on the §5.0 tangent rebake (itself first-build), not Tier-B;
  gate #11 depends only on the caps asset (first-build) + the archetype roster. No first-build item depends
  on a deferred one. The acknowledged-open items (default-interval `[a,b]` shapes + `f`,
  combination-plausibility, Tier-B baker, subdivision cost, procedural-iris taste, Quest costs,
  self-intersection limit) each have a sound, named seam and none breaks a first-build item — not flaws per
  the contract.

---

## Summary

- **MA14-1 (MAJOR):** a mid-gesture raw RESTORE (Ctrl+Z / Ctrl+Shift+Z, keyboard-reachable while a mouse
  drag is held) replaces `_body_state.modifiers` wholesale but does not end the gesture or clear the v14
  `_drag_start_value` map (`character_creator.gd:576-583,1299-1331,647-648`; `SYNTHESIS.md:1050-1057,1064`);
  the gesture then clamps against a stale `cur_start`, so a ratchet the restore removed survives, and the
  drag commits a garbled node. This is exactly the held-interval × raw-restore interaction the design
  hardened in one direction (no capture) but left open in the other (no clear). The symmetric extremeness-
  mid-gesture conflict WAS handled (MI12-1); the restore-mid-gesture conflict is not mentioned.
- **MI14-1 (MINOR, pre-v14 / scoped):** a bilateral region slider drives two controls but is one widget;
  under the v14 step-4 protocol the displayed bounds are the last-processed resolved name's, so for a
  diverged (asymmetric) L/R the thumb range can exceed one side's true cap (`region_sliders.gd:136-145`,
  `character_creator.gd:1168-1186`, `SYNTHESIS.md:599-604`). The per-control held interval is still correct;
  only the shared widget display is ambiguous, a limitation predating the cap model.
- The v14 choke-capture invariant (MA13-1) and the full all-controls gesture-end sweep (MI13-1) are
  re-verified sound for every write path that flows through `apply_capped`; concerns (1)–(3) and the
  no-capture half of (4) are clean against the actual code. The core cap formula is unchanged and sound.
